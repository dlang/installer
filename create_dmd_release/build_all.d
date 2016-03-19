/++
Prerequisites:
-------------------------
A working dmd installation to compile this script (also requires libcurl).
Install Vagrant (https://learnchef.opscode.com/screencasts/install-vagrant/)
Install VirtualBox (https://learnchef.opscode.com/screencasts/install-virtual-box/)
+/
import std.algorithm, std.conv, std.exception, std.file, std.path, std.process, std.stdio, std.string, std.range;
import common;

version (Posix) {} else { static assert(0, "This must be run on a Posix machine."); }
static assert(__VERSION__ >= 2067, "Requires dmd >= 2.067 with a fix for Bugzilla 8269.");

/// Open Source OS boxes are from http://www.vagrantbox.es/
/// For each box additional setup steps were performed, afterwards the boxes were repackaged.

/// Name: create_dmd_release-freebsd-64
/// VagrantBox.es: FreeBSD 8.4 i386 (minimal, No Guest Additions, UFS)
/// URL: http://dlang.dawg.eu/vagrant/FreeBSD-8.4-i386.box
/// Setup: sudo pkg_add -r curl git gmake rsync
enum freebsd_32 = Platform(OS.freebsd, Model._32);

/// Name: create_dmd_release-freebsd-64
/// VagrantBox.es: FreeBSD 8.4 amd64 (minimal, No Guest Additions, UFS)
/// URL: http://dlang.dawg.eu/vagrant/FreeBSD-8.4-amd64.box
/// Setup: sudo pkg_add -r curl git gmake rsync
enum freebsd_64 = Platform(OS.freebsd, Model._64);

/// Name: create_dmd_release-linux
/// VagrantBox.es: Opscode debian-7.4
/// URL: http://opscode-vm-bento.s3.amazonaws.com/vagrant/virtualbox/opscode_debian-7.4_chef-provisionerless.box
/// Setup: sudo apt-get -y update; sudo apt-get -y install git g++-multilib dpkg-dev rpm unzip;
enum linux_both = Platform(OS.linux, Model._both);

/// OSes that require licenses must be setup manually

/// Name: create_dmd_release-osx
/// Setup: Preparing OSX-10.8 box, https://gist.github.com/MartinNowak/8156507
enum osx_both = Platform(OS.osx, Model._both);

/// Name: create_dmd_release-windows
/// Setup: Preparing Win7x64 box, https://gist.github.com/MartinNowak/8270666
enum windows_both = Platform(OS.windows, Model._both);

enum platforms = [linux_both, windows_both, osx_both, freebsd_32, freebsd_64];


enum OS { freebsd, linux, osx, windows, }
enum Model { _both = 0, _32 = 32, _64 = 64 }
struct Platform
{
    @property string osS() { return to!string(os); }
    @property string modelS() { return model == Model._both ? "" : to!string(cast(uint)model); }
    string toString() { return model == Model._both ? osS : osS ~ "-" ~ modelS; }
    OS os;
    Model model;
}

struct Shell
{
    @disable this(this);

    this(string[] args)
    {
        _pipes = pipeProcess(args, Redirect.stdin);
    }

    void cmd(string s)
    {
        writeln("\033[33m", s, "\033[0m");
        _pipes.stdin.writeln(s);
    }

    ~this()
    {
        _pipes.stdin.close();
        // TODO: capture stderr and attach it to enforce
        enforce(wait(_pipes.pid) == 0);
    }

    ProcessPipes _pipes;
}

struct Box
{
    @disable this(this);

    this(Platform platform)
    {
        _platform = platform;

        _tmpdir = mkdtemp();
        std.file.write(buildPath(_tmpdir, "Vagrantfile"), vagrantFile);

        // bring up the virtual box (downloads missing images)
        run("cd "~_tmpdir~"; vagrant up");
        _isUp = true;

        // save the ssh config file
        run("cd "~_tmpdir~"; vagrant ssh-config > ssh.cfg;");
        if (os == OS.windows)
            run("cd "~_tmpdir~"; echo '     HostKeyAlgorithms ssh-dss' >> ssh.cfg;");
    }

    Shell shell()
    {
        if (os == OS.windows)
            return Shell(["ssh", "-F", sshcfg, "default", "powershell", "-Command", "-"]);
        else
            return Shell(["ssh", "-F", sshcfg, "default", "bash", "-e"]);
    }

    void scp(string src, string tgt)
    {
        if (os == OS.windows)
            run("scp -rq -F "~sshcfg~" "~src~" "~tgt);
        else
            run("rsync -a -e 'ssh -F "~sshcfg~"' "~src~" "~tgt);
    }

private:
    @property string vagrantFile()
    {
        auto res =
            `
            VAGRANTFILE_API_VERSION = "2"

            Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
                config.vm.box = "create_dmd_release-`~platform~`"
                # disable shared folders, because the guest additions are missing
                config.vm.synced_folder ".", "/vagrant", :disabled => true
                # use insecure ssh keys
                config.ssh.insert_key = false

                config.vm.provider :virtualbox do |vb|
                  vb.customize ["modifyvm", :id, "--memory", "4096"]
                  vb.customize ["modifyvm", :id, "--cpus", "4"]
                  vb.customize ["modifyvm", :id, "--accelerate3d", "off"]
                  vb.customize ["modifyvm", :id, "--audio", "none"]
                  vb.customize ["modifyvm", :id, "--usb", "off"]
                end
            `;
        if (os == OS.windows)
            res ~=
            `
                config.ssh.shell = 'powershell -Command -'
                config.vm.guest = :windows
            `;
        res ~=
            `
            end
            `;
        return res.outdent();
    }

    auto build(string ver, bool isBranch, bool skipDocs)
    {
        return runBuild(this, ver, isBranch, skipDocs);
    }

    ~this()
    {
        destroy();
    }

    void destroy()
    {
        try
        {
            if (_isUp) run("cd "~_tmpdir~"; vagrant destroy -f");
            if (_tmpdir.length) rmdirRecurse(_tmpdir);
        }
        finally
        {
            _isUp = false;
            _tmpdir = null;
        }
    }

    void halt()
    {
        try
            if (_isUp) run("cd "~_tmpdir~"; vagrant halt");
        finally
            _isUp = false;
    }

    @property string platform() { return _platform.toString; }
    @property string sshcfg() { return buildPath(_tmpdir, "ssh.cfg"); }

    Platform _platform;
    alias _platform this;
    string _tmpdir;
    bool _isUp;
}

string runCapture(string cmd)
{
    writeln("\033[36m", cmd, "\033[0m");
    auto result = executeShell(cmd);
    enforce(result.status == 0);
    return result.output.strip;
}

void run(string cmd)
{
    writeln("\033[36m", cmd, "\033[0m");
    enforce(wait(spawnShell(cmd)) == 0);
}

//------------------------------------------------------------------------------

auto addPrefix(R)(R rng, string prefix)
{
    import std.algorithm : map;
    return rng.map!(a => prefix ~ a)();
}

//------------------------------------------------------------------------------
// Copy additional release binaries from the previous release

void prepareExtraBins(string workDir)
{
    auto winBins = [
        "windbg.hlp", "ddemangle.exe", "lib.exe", "link.exe", "make.exe",
        "replace.exe", "shell.exe", "windbg.exe", "dm.dll", "eecxxx86.dll",
        "emx86.dll", "mspdb41.dll", "shcv.dll", "tlloc.dll", "libcurl.dll",
    ].addPrefix("bin/");
    auto winBins64 = ["libcurl.dll"].addPrefix("bin64/");
    auto winLibs = [
        "advapi32.lib", "COMCTL32.LIB", "comdlg32.lib", "CTL3D32.LIB",
        "gdi32.lib", "kernel32.lib", "ODBC32.LIB", "ole32.lib", "OLEAUT32.LIB",
        "rpcrt4.lib", "shell32.lib", "snn.lib", "user32.lib", "uuid.lib",
        "winmm.lib", "winspool.lib", "WS2_32.LIB", "wsock32.lib", "curl.lib",
    ].addPrefix("lib/");
    auto winLibs64 = ["curl.lib"].addPrefix("lib64/");
    auto winFiles = chain(winBins, winBins64, winLibs, winLibs64).array();

    auto extraBins = [
        windows_both : winFiles,
        linux_both : ["bin32/dumpobj", "bin64/dumpobj", "bin32/obj2asm", "bin64/obj2asm"],
        freebsd_32 : ["bin32/dumpobj", "bin32/obj2asm", "bin32/shell"],
        freebsd_64 : [],
        osx_both : ["bin/dumpobj", "bin/obj2asm", "bin/shell"],
    ];

    foreach (platform; platforms)
        copyFiles(extraBins[platform].addPrefix("dmd2/"~platform.osS~"/").array(),
                  workDir~"/"~platform.toString~"/old-dmd", workDir~"/"~platform.osS~"/extraBins");
}

//------------------------------------------------------------------------------
// builds a dmd.VERSION.OS.MODEL.zip on the vanilla VirtualBox image

void runBuild(ref Box box, string ver, bool isBranch, bool skipDocs)
{
    with (box.shell())
    {
        string dmd, rdmd;
        final switch (box.os)
        {
        case OS.freebsd:
            dmd = "old-dmd/dmd2/freebsd/bin"~box.modelS~"/dmd";
            rdmd = "old-dmd/dmd2/freebsd/bin"~box.modelS~"/rdmd"~" --compiler="~dmd;
            break;
        case OS.linux:
            dmd = "old-dmd/dmd2/linux/bin64/dmd";
            rdmd = "old-dmd/dmd2/linux/bin64/rdmd --compiler="~dmd;
            break;
        case OS.windows:
            // update DMC's snn.lib and link.exe
            cmd(`copy old-dmd\dmd2\windows\bin\link.exe C:\dm\bin\link.exe`);
            cmd(`copy old-dmd\dmd2\windows\lib\snn.lib C:\dm\lib\snn.lib`);
            // copy libcurl needed for create_dmd_release and dlang.org
            cmd(`copy old-dmd\dmd2\windows\bin\libcurl.dll .`);
            cmd(`copy old-dmd\dmd2\windows\bin\libcurl.dll clones\dlang.org`);
            cmd(`copy old-dmd\dmd2\windows\lib\curl.lib clones\dlang.org`);

            dmd = `old-dmd\dmd2\windows\bin\dmd.exe`;
            rdmd = `old-dmd\dmd2\windows\bin\rdmd.exe --compiler=`~dmd;
            break;
        case OS.osx:
            dmd = "old-dmd/dmd2/osx/bin/dmd";
            rdmd = "old-dmd/dmd2/osx/bin/rdmd --compiler="~dmd;
            break;
        }

        auto build = rdmd~" create_dmd_release --extras=extraBins --use-clone=clones --host-dmd="~dmd;
        if (box.model != Model._both)
            build ~= " --only-" ~ box.modelS;
        if (skipDocs)
            build ~= " --skip-docs";
        build ~= " " ~ ver;

        cmd(build);
    }

    // copy out created zip files
    box.scp("default:dmd."~ver~"."~box.platform~".zip", "build/");

    // Build package installers
    if (!isBranch && !skipDocs) final switch (box.os)
    {
    case OS.freebsd:
        break;

    case OS.linux:
        with (box.shell())
        {
            cmd(`cp dmd.`~ver~`.linux.zip clones/installer/linux`);
            cmd(`cd clones/installer/linux`);
            cmd(`./build_all.sh -v`~ver);
            cmd(`ls *.deb`);
        }
        box.scp("'default:clones/installer/linux/*.{rpm,deb}'", "build/");
        break;

    case OS.windows:
        with (box.shell())
        {
            cmd(`cd clones\installer\windows`);
            cmd(`&'C:\Program Files (x86)\NSIS\makensis'`~
                ` '/DEmbedD2Dir=C:\Users\vagrant\dmd.`~ver~`.windows\dmd2'`~
                ` '/DVersion2=`~ver~`' d2-installer.nsi`);
            cmd(`copy dmd-`~ver~`.exe C:\Users\vagrant\dmd-`~ver~`.exe`);
        }
        box.scp("default:dmd-"~ver~".exe", "build/");
        break;

    case OS.osx:
        with (box.shell())
        {
            cmd(`cp dmd.`~ver~`.osx.zip clones/installer/osx`);
            cmd(`cd clones/installer/osx`);
            cmd(`make dmd.`~ver~`.dmg VERSION=`~ver);
        }
        box.scp("'default:clones/installer/osx/*.dmg'", "build/");
        break;
    }
}

void cloneSources(string gitTag, string tgtDir)
{
    auto prefix = "https://github.com/D-Programming-Language/";
    auto fmt = "git clone --depth 1 -b "~gitTag~" "~prefix~"%1$s.git "~tgtDir~"/%1$s";
    foreach (proj; allProjects)
        run(fmt.format(proj));
}

void applyPatches(string gitTag, string tgtDir)
{
    auto fmt = "git -C "~tgtDir~"/%1$s apply -3 < patches/%1$s.patch";
    foreach (proj; ["dlang.org", "tools"])
        run(fmt.format(proj));
}

auto lzmaExt = (OS os) => os == OS.windows ? ".7z" : ".tar.xz";

void lzmaArchives(string gitTag)
{
    auto baseName = "build/dmd."~gitTag~".";

    foreach (platform; platforms)
    {
        auto workDir = mkdtemp();
        scope (success) if (workDir.exists) rmdirRecurse(workDir);

        auto name = baseName ~ platform.toString;
        writeln("Building LZMA archive '", name~lzmaExt(platform.os), "'.");
        extractZip(name ~ ".zip", workDir);
        archiveLZMA(workDir~"/dmd2", name~lzmaExt(platform.os));
    }
}

int error(Args...)(string fmt, Args args)
{
    stderr.write("\033[031m");
    scope (exit) stderr.write("\033[0m");
    stderr.writefln(fmt, args);
    import core.stdc.stdlib : EXIT_FAILURE;
    return EXIT_FAILURE;
}

int main(string[] args)
{
    if (args.length < 3 || args.length == 4 && args[$-1] != "--skip-docs" || args.length > 4)
        return error("Expected <old-dmd-version> <git-branch-or-tag> [--skip-docs] as arguments, e.g. 'rdmd build_all v2.066.0 v2.066.1'.");
    immutable skipDocs = args[$-1] == "--skip-docs";

    import std.regex;
    enum verRE = regex(`^v(\d+)\.(\d+)\.(\d+)(-.*)?$`);

    auto workDir = mkdtemp();
    scope (success) if (workDir.exists) rmdirRecurse(workDir);
    // Cache huge downloads
    enum cacheDir = "cached_downloads";

    auto oldVer = args[1];
    if (!oldVer.match(verRE))
        return error("Expected a version tag like 'v2.066.0' not '%s'", oldVer);
    oldVer = oldVer.chompPrefix("v");

    immutable gitTag = args[2];
    immutable isBranch = !gitTag.match(verRE);

    enum optlink = "optlink.zip";
    enum libC = "snn.lib";
    enum libCurl = "libcurl-7.47.1-WinSSL-zlib-x86-x64.zip";

    auto oldCompilers = platforms
        .map!(p => "dmd.%1$s.%2$s.%3$s".format(oldVer, p, p.os == OS.windows ? "7z" : "tar.xz"));

    foreach (url; oldCompilers.map!(s => "http://downloads.dlang.org/releases/2.x/"~oldVer~"/"~s))
        fetchFile(url, cacheDir~"/"~baseName(url), true);
    fetchFile("http://ftp.digitalmars.com/"~optlink, cacheDir~"/"~optlink);
    fetchFile("http://ftp.digitalmars.com/"~libC, cacheDir~"/"~libC);
    fetchFile("http://downloads.dlang.org/other/"~libCurl, cacheDir~"/"~libCurl, true);

    // Unpack previous dmd release
    foreach (platform, oldCompiler; platforms.zip(oldCompilers))
        extract(cacheDir~"/"~oldCompiler, workDir~"/"~platform.toString~"/old-dmd");

    if (platforms.canFind!(p => p.os == OS.windows))
    {
        // Use latest optlink
        remove(workDir~"/windows/old-dmd/dmd2/windows/bin/link.exe");
        extract(cacheDir~"/"~optlink, workDir~"/windows/old-dmd/dmd2/windows/bin/");
        // Use latest libC (snn.lib)
        remove(workDir~"/windows/old-dmd/dmd2/windows/lib/snn.lib");
        copyFile(cacheDir~"/"~libC, workDir~"/windows/old-dmd/dmd2/windows/lib/"~libC);
        // Get libcurl for windows
        extract(cacheDir~"/"~libCurl, workDir~"/windows/old-dmd/");
    }

    cloneSources(gitTag, workDir~"/clones");
    immutable dmdVersion = workDir~"/clones/dmd/VERSION";
    if (isBranch)
    {
        auto commit = runCapture("git -C "~workDir~"/clones/dmd rev-parse --short HEAD");
        std.file.write(dmdVersion, readText(dmdVersion).strip~"-"~gitTag~"-"~commit);
    }
    else
    {
        std.file.write(dmdVersion, gitTag.chompPrefix("v"));
    }
    applyPatches(gitTag, workDir~"/clones");
    prepareExtraBins(workDir);

    immutable ver = gitTag.chompPrefix("v");
    mkdirRecurse("build");

    foreach (p; platforms)
    {
        with (Box(p))
        {
            auto toCopy = [platform~"/old-dmd", "clones", osS~"/extraBins"].addPrefix(workDir~"/").join(" ");
            scp(toCopy, "default:");
            if (os != OS.linux && !skipDocs) scp(workDir~"/docs", "default:");
            // copy create_dmd_release.d and dependencies
            scp("create_dmd_release.d common.d", "default:");

            build(ver, isBranch, skipDocs);
            if (os == OS.linux && !skipDocs) scp("default:docs", workDir);
        }
    }
    lzmaArchives(ver);
    return 0;
}
