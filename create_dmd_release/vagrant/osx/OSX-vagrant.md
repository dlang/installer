## Preparing OSX-10.8.box
- Open [OSX-10.8.ova][] in VirtualBox
    1. Select File/Import Appliance
- Install OSX (boot from InstallESD.dmg in "Install Mac OS X Mountain Lion.app")
    1. Create single partition
    1. Add vagrant user (password: vagrant)
- Login as vagrant
    1. run setup.sh
        - curl -L https://gist.github.com/MartinNowak/8156507/raw/setup.sh | sudo sh
    1. install [XCode command line tools](https://developer.apple.com/downloads/index.action?name=Command%20Line%20Tools)
    1. install [PackageManager (Auxillary XCode tools)](https://developer.apple.com/downloads/index.action?name=PackageMaker)
    1. shutdown
- Package box
    - vagrant package --base OSX-10.8 --output OSX-10.8.box

[OSX-10.8.ova]: https://gist.github.com/MartinNowak/8156507/raw/OSX-10.8.ova
