Setting up the vagrant boxes
----------------------------

If you don't want to build the Open-Source boxes yourself, simply fetch them from vagrant:

```
vagrant box add wilzbach/create_dmd_release-linux
mv ~/.vagrant.d/boxes/wilzbach-VAGRANTSLASH-create_dmd_release-linux \
        ~/.vagrant.d/boxes/create_dmd_release-linux

vagrant box add wilzbach/create_dmd_release-freebsd-32
mv ~/.vagrant.d/boxes/wilzbach-VAGRANTSLASH-create_dmd_release-freebsd-32 \
 vagrant box add wilzbach/create_dmd_release-freebsd-32

vagrant box add wilzbach/create_dmd_release-freebsd-64
mv ~/.vagrant.d/boxes/wilzbach-VAGRANTSLASH-create_dmd_release-freebsd-64 \
 vagrant box add wilzbach/create_dmd_release-freebsd-64
```

For building the individual boxes yourself from source, see the respective folders.
Due to licensing, you will need to build at least the OSX and Windows boxes yourself.

Building a box yourself
-----------------------

Linux
-----

```
vagrant up
vagrant package
vagrant box add create_dmd_release-linux package.box
vagrant destroy
```

Windows
-------

TODO

MacOSX
-------

TODO
