/++
Prerequisites:
-------------------------
A working dmd installation to compile this script (also requires libcurl).
Install Vagrant (https://learnchef.opscode.com/screencasts/install-vagrant/)
Install VirtualBox (https://learnchef.opscode.com/screencasts/install-virtual-box/)
+/
import std.conv, std.exception, std.file, std.path, std.process, std.stdio, std.string;
import common;

version (Posix) {} else { static assert(0, "This must be run on a Posix machine."); }

// from http://www.vagrantbox.es/

// FreeBSD 8.4 i386 (minimal, No Guest Additions, UFS)
enum freebsd_32 = Box(OS.freebsd, Model._32, "http://dlang.dawg.eu/vagrant/FreeBSD-8.4-i386.box",
                      "sudo pkg_add -r curl git gmake;");

// FreeBSD 8.4 amd64 (minimal, No Guest Additions, UFS)
enum freebsd_64 = Box(OS.freebsd, Model._64, "http://dlang.dawg.eu/vagrant/FreeBSD-8.4-amd64.box",
                      "sudo pkg_add -r curl git gmake;");

// Puppetlabs Debian 6.0.7 x86_64, VBox 4.2.10, No Puppet or Chef
enum linux_both = Box(OS.linux, Model._both, "http://puppet-vagrant-boxes.puppetlabs.com/debian-607-x64-vbox4210-nocm.box",
                    "sudo apt-get -y update; sudo apt-get -y install git g++-multilib;");

// local boxes

// Preparing OSX-10.8 box, https://gist.github.com/MartinNowak/8156507
enum osx_both = Box(OS.osx, Model._both, null,
                  null);

// Preparing Win7x64 box, https://gist.github.com/MartinNowak/8270666
enum windows_both = Box(OS.windows, Model._both, null,
                  null);

enum boxes = [freebsd_32, freebsd_64, linux_both, osx_both, windows_both];


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
            if (_isUp) run("cd "~_tmpdir~" && vagrant halt -f");
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
        // download create_dmd_release binary
        auto baseURL = "http://dlang.dawg.eu/download/create_dmd_release-"~platform;
        if (_os == OS.windows)
        {
            sh.exec(`(new-object System.Net.WebClient).DownloadFile('`~baseURL~`.zip', 'C:\Users\vagrant\cdr.zip')`);
            sh.exec(`$shell = new-object -com shell.application`);
            sh.exec(`$shell.NameSpace('C:\Users\vagrant').CopyHere($shell.NameSpace('C:\Users\vagrant\cdr.zip').Items(), 0x14)`);
            sh.exec(`del 'C:\Users\vagrant\cdr.zip'`);
        }
        else
        {
            sh.exec(`curl `~baseURL~`.tar.gz | tar -zxf -`);
        }
        // wait for completion
        sh.close();
    }

    void run(string cmd) { writeln("\033[36m", cmd, "\033[0m"); enforce(wait(spawnShell(cmd)) == 0); }
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

// builds a dmd.VERSION.OS.MODEL.zip on the vanilla VirtualBox image
void runBuild(Box box, string gitTag)
{
    box.up();
    scope (success) box.destroy();
    scope (failure) box.halt();

    auto sh = box.shell();

    auto cmd = "./create_dmd_release --extras=localextras-"~box.osS~" --archive";
    if (box._model != Model._both)
        cmd ~= " --only-" ~ box.modelS;
    cmd ~= " " ~ gitTag;

    sh.exec(cmd);
    sh.close();
    // copy out created zip file
    box.scp("default:dmd."~gitTag~"."~box.platform~".zip", ".");
}

void combine(string gitTag)
{
    auto box = linux_both;
    box.up();
    scope (success) box.destroy();
    scope (failure) box.halt();

    // copy local zip files to the box
    foreach (b; boxes)
    {
        auto zip = "dmd."~gitTag~"."~b.platform~".zip";
        box.scp(zip, "default:"~zip);
    }
    // combine zips
    auto sh = box.shell();
    sh.exec("./create_dmd_release --combine "~gitTag);
    sh.close();
    // copy out resulting zip
    box.scp("default:"~"dmd."~gitTag~".zip", ".");
}

int main(string[] args)
{
    if (args.length != 2)
    {
        stderr.writeln("Expected <git-branch-or-tag> as only argument, e.g. v2.064.2.");
        return 1;
    }

    auto gitTag = args[1];
    auto workDir = mkdtemp();
    scope (success) if (workDir.exists) rmdirRecurse(workDir);
    // Cache huge downloads
    enum cacheDir = "cached_downloads";

    enum oldDMD = "dmd.2.065.b1.zip"; // TODO: determine from gitTag
    enum optlink = "optlink.zip";
    enum libCurl = "libcurl-7.34.0-WinSSL-zlib-x86-x64.zip";

    fetchFile("http://ftp.digitalmars.com/"~oldDMD, cacheDir~"/"~oldDMD);
    fetchFile("http://ftp.digitalmars.com/"~optlink, cacheDir~"/"~optlink);
    fetchFile("http://downloads.dlang.org/other/"~libCurl, cacheDir~"/"~libCurl);

    // Get previous dmd release
    extractZip(cacheDir~"/"~oldDMD, workDir~"/old-dmd");
    // Get latest optlink
    remove(workDir~"/old-dmd/dmd2/windows/bin/link.exe");
    extractZip(cacheDir~"/"~optlink, workDir~"/old-dmd/dmd2/windows/bin");
    // Get libcurl for windows
    extractZip(cacheDir~"/"~libCurl, workDir~"/old-dmd");

    // Get missing FreeBSD dmd.conf, this is a bug in 2.065.0-b1 and should be fixed in newer releases
    fetchFile(
        "https://raw.github.com/D-Programming-Language/dmd/"~gitTag~"/ini/freebsd/bin32/dmd.conf",
        buildPath(workDir, "old-dmd/dmd2/freebsd/bin32/dmd.conf"));

    fetchFile(
        "https://raw.github.com/D-Programming-Language/dmd/"~gitTag~"/ini/freebsd/bin64/dmd.conf",
        buildPath(workDir, "old-dmd/dmd2/freebsd/bin64/dmd.conf"));

    foreach (box; boxes)
        runBuild(box, gitTag);
    combine(gitTag);
    return 0;
}
