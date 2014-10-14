/++
Prerequisites:
-------------------------
A working dmd installation to compile this script (also requires libcurl).
Install Vagrant (https://learnchef.opscode.com/screencasts/install-vagrant/)
Install VirtualBox (https://learnchef.opscode.com/screencasts/install-virtual-box/)
+/
import std.conv, std.exception, std.file, std.path, std.process, std.stdio, std.string, std.range;
import common;

version (Posix) {} else { static assert(0, "This must be run on a Posix machine."); }

// Open Source OS boxes are from http://www.vagrantbox.es/
// Note: The pull request to add the FreeBSD-8.4 boxes to vagrantbox.es is still pending, https://github.com/garethr/vagrantboxes-heroku/pull/246.

/// Name: create_dmd_release-freebsd-64
/// VagrantBox.es: FreeBSD 8.4 i386 (minimal, No Guest Additions, UFS)
enum freebsd_32 = Box(OS.freebsd, Model._32, "http://dlang.dawg.eu/vagrant/FreeBSD-8.4-i386.box",
                      "sudo pkg_add -r curl git gmake;");

// Note: pull request for vagrantbox.es pending
/// Name: create_dmd_release-freebsd-64
/// VagrantBox.es: FreeBSD 8.4 amd64 (minimal, No Guest Additions, UFS)
enum freebsd_64 = Box(OS.freebsd, Model._64, "http://dlang.dawg.eu/vagrant/FreeBSD-8.4-amd64.box",
                      "sudo pkg_add -r curl git gmake;");

/// Name: create_dmd_release-linux
/// VagrantBox.es: Puppetlabs Debian 6.0.7 x86_64, VBox 4.2.10, No Puppet or Chef
enum linux_both = Box(OS.linux, Model._both, "http://puppet-vagrant-boxes.puppetlabs.com/debian-607-x64-vbox4210-nocm.box",
                    "sudo apt-get -y update; sudo apt-get -y install git g++-multilib;");

/// OSes that require licenses must be setup manually

/// Name: create_dmd_release-osx
/// Setup: Preparing OSX-10.8 box, https://gist.github.com/MartinNowak/8156507
enum osx_both = Box(OS.osx, Model._both, null,
                  null);

/// Name: create_dmd_release-windows
/// Setup: Preparing Win7x64 box, https://gist.github.com/MartinNowak/8270666
enum windows_both = Box(OS.windows, Model._both, null,
                  null);

enum boxes = [windows_both, osx_both, freebsd_32, freebsd_64, linux_both];


enum OS { freebsd, linux, osx, windows, }
enum Model { _both = 0, _32 = 32, _64 = 64 }

struct Box
{
    void up()
    {
        _tmpdir = mkdtemp();
        std.file.write(buildPath(_tmpdir, "Vagrantfile"), vagrantFile);

        // bring up the virtual box (downloads missing images)
        run("cd "~_tmpdir~" && vagrant up");

        _isUp = true;

        // save the ssh config file
        run("cd "~_tmpdir~" && vagrant ssh-config > ssh.cfg");

        provision();
    }

    void destroy()
    {
        try
        {
            if (_isUp) run("cd "~_tmpdir~" && vagrant destroy -f");
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
            if (_isUp) run("cd "~_tmpdir~" && vagrant halt");
        finally
            _isUp = false;
    }

    ProcessPipes shell(Redirect redirect = Redirect.stdin)
    in { assert(redirect & Redirect.stdin); }
    body
    {
        ProcessPipes sh;
        if (_os == OS.windows)
        {
            sh = pipeProcess(["ssh", "-F", sshcfg, "default", "powershell", "-Command", "-"], redirect);
        }
        else
        {
            sh = pipeProcess(["ssh", "-F", sshcfg, "default", "bash"], redirect);
            // enable verbose echo and stop on error
            sh.exec("set -e -v");
        }
        return sh;
    }

    void scp(string src, string tgt)
    {
        run("scp -rq -F "~sshcfg~" "~src~" "~tgt);
    }

private:
    @property string vagrantFile()
    {
        auto res =
            `
            VAGRANTFILE_API_VERSION = "2"

            Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
                config.vm.box = "create_dmd_release-`~platform~`"
                config.vm.box_url = "`~_url~`"
                # disable shared folders, because the guest additions are missing
                config.vm.synced_folder ".", "/vagrant", :disabled => true

                config.vm.provider :virtualbox do |vb|
                  vb.customize ["modifyvm", :id, "--memory", "4096"]
                  vb.customize ["modifyvm", :id, "--cpus", "4"]
                  vb.customize ["modifyvm", :id, "--accelerate3d", "off"]
                  vb.customize ["modifyvm", :id, "--audio", "none"]
                  vb.customize ["modifyvm", :id, "--usb", "off"]
                end
            `;
        if (_os == OS.windows)
            res ~=
            `
                config.vm.guest = :windows
                # Port forward WinRM and RDP
                config.vm.network :forwarded_port, guest: 3389, host: 3389
                config.vm.network :forwarded_port, guest: 5985, host: 5985, id: "winrm", auto_correct: true
            `;
        res ~=
            `
            end
            `;
        return res.outdent();
    }

    void provision()
    {
        auto sh = shell();
        // install prerequisites
        sh.exec(_setup);
        // wait for completion
        sh.close();
    }

    @property string platform() { return _model == Model._both ? osS : osS ~ "-" ~ modelS; }
    @property string osS() { return to!string(_os); }
    @property string modelS() { return _model == Model._both ? "" : to!string(cast(uint)_model); }
    @property string sshcfg() { return buildPath(_tmpdir, "ssh.cfg"); }

    OS _os;
    Model _model;
    string _url; /// optional url of the image
    string _setup; /// initial provisioning script
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

void exec(ProcessPipes pipes, string cmd)
{
    writeln("\033[33m", cmd, "\033[0m");
    pipes.stdin.writeln(cmd);
}

void close(ProcessPipes pipes)
{
    pipes.stdin.close();
    // TODO: capture stderr and attach it to enforce
    enforce(wait(pipes.pid) == 0);
}

//------------------------------------------------------------------------------

auto addPrefix(R)(R rng, string prefix)
{
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
        "windows" : winFiles,
        "linux" : ["bin32/dumpobj", "bin64/dumpobj", "bin32/obj2asm", "bin64/obj2asm"],
        "freebsd" : ["bin32/dumpobj", "bin32/obj2asm", "bin32/shell"],
        "osx" : ["bin/dumpobj", "bin/obj2asm", "bin/shell"],
    ];

    foreach (os, files; extraBins)
        copyFiles(files.addPrefix("dmd2/"~os~"/").array(),
                  workDir~"/old-dmd", workDir~"/"~os~"/extraBins");
}

//------------------------------------------------------------------------------
// builds a dmd.VERSION.OS.MODEL.zip on the vanilla VirtualBox image

void runBuild(Box box, string gitTag, bool isBranch, bool combine)
{
    auto sh = box.shell();

    string rdmd;
    final switch (box._os)
    {
    case OS.freebsd:
        rdmd = "old-dmd/dmd2/freebsd/bin"~box.modelS~"/rdmd"~
            " --compiler=old-dmd/dmd2/freebsd/bin"~box.modelS~"/dmd";
        break;
    case OS.linux:
        rdmd = "old-dmd/dmd2/linux/bin64/rdmd"~
            " --compiler=old-dmd/dmd2/linux/bin64/dmd";
        break;
    case OS.windows:
        // update DMC's snn.lib and link.exe
        sh.exec(`copy old-dmd\dmd2\windows\bin\link.exe C:\dm\bin\link.exe`);
        sh.exec(`copy old-dmd\dmd2\windows\lib\snn.lib C:\dm\lib\snn.lib`);
        // copy libcurl needed for create_dmd_release and dlang.org
        sh.exec(`copy old-dmd\dmd2\windows\bin\libcurl.dll .`);
        sh.exec(`copy old-dmd\dmd2\windows\bin\libcurl.dll clones\dlang.org`);
        sh.exec(`copy old-dmd\dmd2\windows\lib\curl.lib clones\dlang.org`);

        rdmd = `old-dmd\dmd2\windows\bin\rdmd.exe`~
            ` --compiler=old-dmd\dmd2\windows\bin\dmd.exe`;
        break;
    case OS.osx:
        rdmd = "old-dmd/dmd2/osx/bin/rdmd"
            " --compiler=old-dmd/dmd2/osx/bin/dmd";
        break;
    }

    auto cmd = rdmd~" create_dmd_release -v --extras=extraBins --archive --use-clone=clones";
    if (box._model != Model._both)
        cmd ~= " --only-" ~ box.modelS;
    cmd ~= " " ~ gitTag;

    sh.exec(cmd);
    if (combine)
        sh.exec(rdmd~" create_dmd_release -v --extras=extraBins --combine --use-clone=clones "~gitTag);

    sh.close();
    // copy out created zip files
    box.scp("default:dmd."~gitTag~"."~box.platform~".zip", ".");
    if (combine)
        box.scp("default:dmd."~gitTag~".zip", ".");

    // Build package installers
    immutable ver = gitTag.chompPrefix("v");

    if (!isBranch) final switch (box._os)
    {
    case OS.freebsd:
        break;

    case OS.linux:
        // TBD
        break;

    case OS.windows:
    {
        sh = box.shell();
        sh.stdin.writeln(`cd clones\installer\windows`);
        sh.stdin.writeln(`&'C:\Program Files (x86)\NSIS\makensis'`~
                         ` '/DEmbedD2Dir=C:\Users\vagrant\dmd.`~gitTag~`.windows\dmd2'`~
                         ` '/DVersion2=`~ver~`' d2-installer.nsi`);
        sh.stdin.writeln(`copy dmd-`~ver~`.exe C:\Users\vagrant\dmd-`~ver~`.exe`);
        sh.close();
        box.scp("default:dmd-"~ver~".exe", ".");
    }
    break;

    case OS.osx:
        // TBD
        break;
    }
}

void cloneSources(string gitTag, string tgtDir)
{
    auto prefix = "https://github.com/D-Programming-Language/";
    auto fmt = "git clone --depth 1 -b "~gitTag~" "~prefix~"%1$s.git "~tgtDir~"/%1$s";
    foreach (proj; allProjects)
        run(fmt.format(proj));

    import std.file;
    write(tgtDir~"/dmd/VERSION", gitTag.chompPrefix("v"));
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
    if (args.length != 3)
        return error("Expected <old-dmd-version> <git-branch-or-tag> as arguments, e.g. 'rdmd build_all v2.066.0 v2.066.1'.");

    import std.regex;
    enum verRE = regex(`^v(\d+)\.(\d+)\.(\d+)(-.*)?$`);

    auto workDir = mkdtemp();
    scope (success) if (workDir.exists) rmdirRecurse(workDir);
    // Cache huge downloads
    enum cacheDir = "cached_downloads";

    immutable oldVer = args[1];
    if (!oldVer.match(verRE))
        return error("Expected a version tag like 'v2.066.0' not '%s'", oldVer);
    immutable oldDMD = "dmd." ~ oldVer["v".length .. $] ~ ".zip";

    immutable gitTag = args[2];
    immutable isBranch = !gitTag.match(verRE);

    enum optlink = "optlink.zip";
    enum libC = "snn.lib";
    enum libCurl = "libcurl-7.38.0-WinSSL-zlib-x86-x64.zip";

    fetchFile("http://ftp.digitalmars.com/"~oldDMD, cacheDir~"/"~oldDMD);
    fetchFile("http://ftp.digitalmars.com/"~optlink, cacheDir~"/"~optlink);
    fetchFile("http://ftp.digitalmars.com/"~libC, cacheDir~"/"~libC);
    fetchFile("http://downloads.dlang.org/other/"~libCurl, cacheDir~"/"~libCurl);

    // Get previous dmd release
    extractZip(cacheDir~"/"~oldDMD, workDir~"/old-dmd");
    // Get latest optlink
    remove(workDir~"/old-dmd/dmd2/windows/bin/link.exe");
    extractZip(cacheDir~"/"~optlink, workDir~"/old-dmd/dmd2/windows/bin");
    // Get latest libC (snn.lib)
    remove(workDir~"/old-dmd/dmd2/windows/lib/snn.lib");
    copyFile(cacheDir~"/"~libC, workDir~"/old-dmd/dmd2/windows/lib/"~libC);
    // Get libcurl for windows
    extractZip(cacheDir~"/"~libCurl, workDir~"/old-dmd");

    cloneSources(gitTag, workDir~"/clones");
    prepareExtraBins(workDir);

    foreach (i, box; boxes)
    {
        immutable combine = i == boxes.length - 1;

        // skip a box if we already have its zip files
        if (("dmd."~gitTag~"."~box.platform~".zip").exists &&
            (!combine || ("dmd."~gitTag~".zip").exists))
        {
            writeln("\033[31m", "Skipping already build platform '"~box.platform~"'.", "\033[0m");
            continue;
        }

        box.up();
        scope (success) box.destroy();
        scope (failure) box.halt();

        auto toCopy = ["old-dmd", "clones", box.osS~"/extraBins"].addPrefix(workDir~"/").join(" ");
        box.scp(toCopy, "default:");
        // copy create_dmd_release.d and dependencies
        box.scp("create_dmd_release.d common.d", "default:");

        // copy all zips into the last box to combine them
        if (combine && boxes.length > 1)
        {
            toCopy = boxes[0 .. $ - 1].map!(b => "dmd."~gitTag~"."~b.platform~".zip").join(" ");
            box.scp(toCopy, "default:");
        }

        runBuild(box, gitTag, isBranch, combine);
    }
    return 0;
}
