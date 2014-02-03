#!/usr/bin/env bash

##
# Author:: Jacob Carlborg
# Version:: Initial created: 2009
# License:: Public Domain
#

sudo -p "Please give your password for uninstallation: " rm -f /usr/bin/ddemangle
sudo -p "Please give your password for uninstallation: " rm -f /usr/bin/dmd
sudo -p "Please give your password for uninstallation: " rm -f /usr/bin/dmd.conf
sudo -p "Please give your password for uninstallation: " rm -f /usr/bin/dumpobj
sudo -p "Please give your password for uninstallation: " rm -f /usr/bin/dustmite
sudo -p "Please give your password for uninstallation: " rm -f /usr/bin/obj2asm
sudo -p "Please give your password for uninstallation: " rm -f /usr/bin/rdmd
sudo -p "Please give your password for uninstallation: " rm -f /usr/share/man/man1/dmd.1
sudo -p "Please give your password for uninstallation: " rm -f /usr/share/man/man1/dumpobj.1
sudo -p "Please give your password for uninstallation: " rm -f /usr/share/man/man1/obj2asm.1
sudo -p "Please give your password for uninstallation: " rm -f /usr/share/man/man1/rdmd.1
sudo -p "Please give your password for uninstallation: " rm -f /usr/share/man/man5/dmd.conf.5
sudo -p "Please give your password for uninstallation: " rm -rf /usr/share/dmd

echo "Uninstallation complete!\n"
