/++
Prerequisites:
-------------------------
A working dmd installation to compile this script (also requires libcurl).
Install Vagrant (https://learnchef.opscode.com/screencasts/install-vagrant/)
Install VirtualBox (https://learnchef.opscode.com/screencasts/install-virtual-box/)
+/
import std.conv, std.exception, std.file, std.path, std.process, std.string, std.net.curl;
pragma(lib, "curl");

version (Posix) {} else { static assert(0, "This must be run on a Posix machine."); }

// from http://www.vagrantbox.es/
enum OS { freebsd, linux, }
enum Model { _32 = 32, _64 = 64, }
struct Box { OS os; Model model; string url; string setup; }

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

enum boxes = [freebsd_32, freebsd_64, linux_32, linux_64];

// builds a dmd.VERSION.OS.MODEL.zip on the vanilla VirtualBox image
void runBuild(Box box, string gitTag)
{
    auto os = to!string(box.os);
    auto model = to!string(cast(uint)box.model);
    auto osmodel = os~"-"~model;

    auto tmpdir = buildPath(tempDir(), "create_dmd_release", osmodel);
    if (tmpdir.exists) rmdirRecurse(tmpdir);
    scope (success) rmdirRecurse(tmpdir);
    mkdirRecurse(tmpdir);

    std.file.write(buildPath(tmpdir, "Vagrantfile"), (`
        VAGRANTFILE_API_VERSION = "2"

        Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
            config.vm.box = "create_dmd_release-`~osmodel~`"
            config.vm.box_url = "`~box.url~`"
            # disable shared folders, because the guest additions are missing
            config.vm.synced_folder ".", "/vagrant", :disabled => true

            config.vm.provider :virtualbox do |vb|
              vb.customize ["modifyvm", :id, "--memory", "4096"]
              vb.customize ["modifyvm", :id, "--cpus", "4"]
            end
        end
   `).outdent().strip());

    scope run = (string cmd) => wait(spawnShell(cmd));
    // bring up the virtual box (downloads missing images)
    run("cd "~tmpdir~" && vagrant up");
    scope (exit) run("cd "~tmpdir~" && vagrant destroy -f");

    // save the ssh config file
    auto sshcfg = buildPath(tmpdir, "ssh.cfg");
    run("cd "~tmpdir~" && vagrant ssh-config > ssh.cfg");
    // open a remove bash session
    auto ssh = pipeProcess(["ssh", "-F", sshcfg, "default", "bash"], Redirect.stdin);
    ssh.stdin.writeln("set -e -v");
    // install prerequisites
    ssh.stdin.writeln(box.setup);
    // download create_dmd_release binary
    ssh.stdin.writeln("curl http://dlang.dawg.eu/download/create_dmd_release-"~osmodel~".tar.gz | tar -zxf -");
    // run ./create_dmd_release
    ssh.stdin.writeln("./create_dmd_release --extras=localextras-"~os~
                      " --archive --only-"~model~" "~gitTag);
    ssh.stdin.close();
    wait(ssh.pid);

    // copy out created zip file
    run("scp -F "~sshcfg~" default:dmd."~gitTag~"."~osmodel~".zip .");
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
    return 0;
}
