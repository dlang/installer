/++
Prerequisites:
-------------------------
A working dmd installation to compile this script (also requires libcurl).
Install Vagrant (https://learnchef.opscode.com/screencasts/install-vagrant/)
Install VirtualBox (https://learnchef.opscode.com/screencasts/install-virtual-box/)
+/
import std.conv, std.exception, std.file, std.path, std.process, std.stdio, std.string, std.net.curl;
pragma(lib, "curl");

version (Posix) {} else { static assert(0, "This must be run on a Posix machine."); }

// from http://www.vagrantbox.es/

// FreeBSD 8.4 i386 (minimal, No Guest Additions, UFS)
enum freebsd_32 = Box(OS.freebsd, Model._32, "http://dlang.dawg.eu/vagrant/FreeBSD-8.4-i386.box",
                      "sudo pkg_add -r curl git gmake;");

// FreeBSD 8.4 amd64 (minimal, No Guest Additions, UFS)
enum freebsd_64 = Box(OS.freebsd, Model._64, "http://dlang.dawg.eu/vagrant/FreeBSD-8.4-amd64.box",
                      "sudo pkg_add -r curl git gmake;");

// Official Ubuntu 12.04 daily Cloud Image i386 (VirtualBox 4.1.12)
enum linux_32 = Box(OS.linux, Model._32, "http://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-i386-vagrant-disk1.box",
                    "sudo apt-get -y install git;");

// Official Ubuntu 12.04 daily Cloud Image amd64 (VirtualBox 4.1.12)
enum linux_64 = Box(OS.linux, Model._64, "http://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box",
                    "sudo apt-get -y install git;");

// local boxes

// Preparing OSX-10.8 box, https://gist.github.com/MartinNowak/8156507
enum osx_both = Box(OS.osx, Model._both, null,
                  null);

enum boxes = [freebsd_32, freebsd_64, linux_32, linux_64, osx_both];


enum OS { freebsd, linux, osx, }
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

    ~this()
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

    ProcessPipes shell(Redirect redirect = Redirect.stdin)
    in { assert(redirect & Redirect.stdin); }
    body
    {
        auto sh = pipeProcess(["ssh", "-F", sshcfg, "default", "bash"], redirect);
        // enable verbose echo and stop on error
        sh.stdin.writeln("set -e -v");
        return sh;
    }

    void scp(string src, string tgt)
    {
        run("scp -F "~sshcfg~" "~src~" "~tgt);
    }

private:
    @property string vagrantFile()
    {
        return (`
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
            end
        `).outdent().strip();
    }

    void provision()
    {
        auto sh = shell();
        // install prerequisites
        sh.stdin.writeln(_setup);
        // download create_dmd_release binary
        sh.stdin.writeln("curl http://dlang.dawg.eu/download/create_dmd_release-"~platform~".tar.gz | tar -zxf -");
        // wait for completion
        sh.close();
    }

    void run(string cmd) { writeln("\033[36m", cmd, "\033[0m"); wait(spawnShell(cmd)); }
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

void close(ProcessPipes pipes)
{
    pipes.stdin.close();
    wait(pipes.pid);
}

extern(C) char* mkdtemp(char* template_);

string mkdtemp()
{
    import core.stdc.string : strlen;

    auto tmp = buildPath(tempDir(), "tmp.XXXXXX\0").dup;
    auto dir = mkdtemp(tmp.ptr);
    return dir[0 .. strlen(dir)].idup;
}

// builds a dmd.VERSION.OS.MODEL.zip on the vanilla VirtualBox image
void runBuild(Box box, string gitTag)
{
    box.up();
    auto sh = box.shell();

    auto cmd = "./create_dmd_release --extras=localextras-"~box.osS~" --archive";
    if (box._model != Model._both)
        cmd ~= " --only-" ~ box.modelS;
    cmd ~= " " ~ gitTag;

    sh.stdin.writeln(cmd);
    sh.close();
    // copy out created zip file
    box.scp("default:dmd."~gitTag~"."~box.platform~".zip", ".");
}

void combine(string gitTag)
{
    auto box = linux_64;
    box.up();
    // copy local zip files to the box
    foreach (b; boxes)
    {
        auto zip = "dmd."~gitTag~"."~b.platform~".zip";
        box.scp(zip, "default:"~zip);
    }
    // combine zips
    auto sh = box.shell();
    sh.stdin.writeln("./create_dmd_release --combine "~gitTag);
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
    foreach (box; boxes)
        runBuild(box, gitTag);
    combine(gitTag);
    return 0;
}
