Mac OS X uses what's called a bundle, it's a directory that acts like a file. If you only
use unix tools like ls and cd you will see the bundles like directories, but if you use
mac tools like Finder (the default file manager application) you will see the bundles like
files. In this case, the pmdoc bundles are the files that PackageMager (the application
used to create installers on mac) create. Another example is the .app bundles, standard
applications with a graphical user interface, contains some meta information, the actual
executable and resource files like icons and images.

The script works like this:

You first unzip the dmd zip file, then run the script like this for example: "./make.rb -d
~/Downloads/dmd -o dmd.1.045".

The script will create, in the current working directory, two directories "dmd" and "dmg".
Then it copies all the files from the path given by the -d switch to dmd. If it finds a
libphobos2.a file it will assume it's dmd2 otherwise dmd1.

The it will copy the dmd.conf or dmd2.conf file into dmd/bin, this is needed because the
installer will create symlinks and the dmd.conf need to have hard coded paths.

Then it will run packagemaker to create the installer, it will use dmd.pmdoc or
dmd2.pmdoc, it contains the GUI for the installer and what and how to install.
packagemaker will also pack post-install.sh, it creates symlinks. It will also package the
contents of the dmd directory into the .pkg file it will create. The .pkg file will be
saved in dmg/DMD then the uninstall.command file will be copied here to, it's a regular
shell script that uninstalls everything, it has ".command" as the file extension because
then you can double click on it in Finder and it will launch a terminal and run the
script.

After the installer is created it will run hdiutil on the dmg directory and create a .dmg
file with the name you gave with the -o switch. It's a disk image file that is similar to
a zip file, but instead of unpack the file you will mount it to get the contents.

Then everything is done, and it's the .dmg file you will distribute.

When you run the installer it will first display some welcome text, the licenses and then
start the installation. It will install dmd in /usr/share/dmd and create symlinks in
/usr/bin and /usr/share/man.

If you only use the mac via ssh, I recommend that use also try the graphical user
interface. It's very easy to enable vnc: Apple Menu -> System Preferences -> Sharing ->
enable Screen Sharing -> Computer Settings... -> VNC viewers ...

You will need the GUI to run PackageMaker and look at the pmdoc files, if you don't want
to read xml.


/Jacob Carlborg 

