## Preparing a Win7x64.box
- Open [Win7x64.ova][] in VirtualBox
    1. Select File/Import Appliance
- Install Windows (boot from [Windows 7 Home Premium with SP1](http://msft.digitalrivercontent.net/win/X17-58997.iso))
    1. Use custom install
    1. Select the whole drive
    1. Wait until the installation finished
    1. Add vagrant user (password: vagrant)
    1. Enter your registration key (select auto activate when connected to the internet)
    1. Choose _Ask me later_ for the auto updates option
    1. Choose _Home Network_ for the network domain
- Login as vagrant
    1. From the VirtualBox Menu
       - choose Devices/Insert Guest Additions CD Image
    1. Install [Windows SDK for Windows 7](http://www.microsoft.com/en-us/download/confirmation.aspx?id=3138)
        - use the _default Destination folders_
        - select the following components
        ![install options](https://gist.github.com/MartinNowak/8270666/raw/win_sdk.png)
    1. Open a powershell console (_Run as administrator_)
        - run the following commands
        ```
        cd \
        (new-object System.Net.WebClient).DownloadFile("https://gist.github.com/MartinNowak/8270666/raw/setup.ps1", "C:\setup.ps1")
        Set-ExecutionPolicy -Force Unrestricted
        .\setup.ps1
        ```
        - This will install WinSSHD, DMC, Git, HTML Help Workshop, NSIS, and
          VirtualBox guest addition and configure WinRM, UAC, and PATH
        - In the popup during the guest addtion install
          - select Always trust software from "Oracle Corporation"
    1. ACPI Shutdown
- Package box
    - vagrant package --base Win7x64 --output Win7x64.box
- Allow to use ssh-dss by adding this to your ~/.ssh/config
```
Host 127.0.0.1
     User vagrant
     HostKeyAlgorithms +ssh-dss
```

[Win7x64.ova]: https://gist.github.com/MartinNowak/8270666/raw/Win7x64.ova
[setup.ps1]: https://gist.github.com/MartinNowak/8270666/raw/setup.ps1
