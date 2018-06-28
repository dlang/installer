#!/bin/sh

set -e -v

# cd $HOME
cd /var/root

# enable passwordless sudo
echo 'vagrant ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# disable software updates
softwareupdate --schedule off
# disable spotlight indexer
mdutil -a -i off

# install ssh keys
mkdir -p .ssh
curl -L https://raw.github.com/mitchellh/vagrant/master/keys/vagrant > .ssh/id_rsa
chmod 0600 .ssh/id_rsa
curl -L https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub > .ssh/id_rsa.pub
cp .ssh/id_rsa.pub .ssh/authorized_keys
cp -r .ssh /Users/vagrant/
chown -R vagrant /Users/vagrant/.ssh

# set network configuration
scutil --set HostName `uname -s`-`uname -r`-`uname -m`

# enable sshd
systemsetup -setremotelogin on

# disable auto login
defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser || echo 0

# TODO: disable gui startup

# install Xcode command line tools
echo "Please install XCode command line tools now."
