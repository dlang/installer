Write-Host -foregroundcolor green 'Disable UAC'
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\policies\system' -Name EnableLUA -Value 0

Write-Host -foregroundcolor green 'Disable Auto Updates'
$au = (new-object -com Microsoft.Update.AutoUpdate).Settings
$au.NotificationLevel = 1
$au.Save()
$au.Refresh()

Write-Host -foregroundcolor green 'Configuring Windows Remote Management'
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
sc.exe config WinRM start= auto

Write-Host -foregroundcolor green 'Installing Bitvise SSH Server'
(new-object System.Net.WebClient).DownloadFile('http://dl.bitvise.com/BvSshServer-Inst.exe', 'C:\BvSshServer-Inst.exe')
(new-object System.Net.WebClient).DownloadFile('https://gist.github.com/MartinNowak/8270666/raw/BvSshServer-Settings.wst', 'C:\BvSshServer-Settings.wst')
.\BvSshServer-Inst.exe -defaultSite -acceptEULA '-settings=BvSshServer-Settings.wst' -activationCode=0000000000000000000000000000000000000000000000000000000005EA7C9C474331F64C7A00020000FFFFFFFFFFFFFFFFFFFFCEA10000
del 'C:\BvSshServer-Inst.exe'
del 'C:\BvSshServer-Settings.wst'

Write-Host -foregroundcolor green 'Installing Digital Mars C Compiler'
(new-object System.Net.WebClient).DownloadFile('http://ftp.digitalmars.com/Digital_Mars_C++/Patch/dm857c.zip', 'C:\dmc.zip')
$shell = new-object -com shell.application
$shell.NameSpace('C:\').CopyHere($shell.NameSpace('C:\dmc.zip').Items(), 0x614)
del 'C:\dmc.zip'

Write-Host -foregroundcolor green 'Updating Digital Mars OPTLINK'
(new-object System.Net.WebClient).DownloadFile('http://ftp.digitalmars.com/optlink.zip', 'C:\optlink.zip')
$shell = new-object -com shell.application
$shell.NameSpace('C:\dm\bin').CopyHere($shell.NameSpace('C:\optlink.zip').Items(), 0x614)
del 'C:\optlink.zip'

Write-Host -foregroundcolor green 'Installing Digital Mars implib'
(new-object System.Net.WebClient).DownloadFile('http://ftp.digitalmars.com/bup.zip', 'C:\bup.zip')
$shell = new-object -com shell.application
$shell.NameSpace('C:\').CopyHere($shell.NameSpace('C:\bup.zip').Items(), 0x614)
del 'C:\bup.zip'

Write-Host -foregroundcolor green 'Installing Git'
(new-object System.Net.WebClient).DownloadFile('https://github.com/git-for-windows/git/releases/download/v2.5.0.windows.1/Git-2.5.0-64-bit.exe', 'C:\git.exe')
(new-object System.Net.WebClient).DownloadFile('https://gist.github.com/MartinNowak/8270666/raw/git.inf', 'C:\git.inf')
Wait-Process -id (Start-Process C:\git.exe -ArgumentList "/SILENT","/LOADINF=git.inf" -PassThru).id
del 'C:\git.exe'

Write-Host -foregroundcolor green 'Installing HTML Help Workshop'
(new-object System.Net.WebClient).DownloadFile('http://download.microsoft.com/download/0/A/9/0A939EF6-E31C-430F-A3DF-DFAE7960D564/htmlhelp.exe', 'C:\htmlhelp.exe')
Wait-Process -id (Start-Process C:\htmlhelp.exe -ArgumentList '"/T:C:\Program Files (x86)\HTML Help Workshop"',"/C","/Q" -PassThru).id
del 'C:\htmlhelp.exe'

Write-Host -foregroundcolor green 'Installing NSIS'
(new-object System.Net.WebClient).DownloadFile('http://sourceforge.net/projects/nsis/files/NSIS%202/2.46/nsis-2.46-setup.exe', 'C:\nsis-2.46-setup.exe')
(new-object System.Net.WebClient).DownloadFile('http://downloads.sourceforge.net/project/nsis/NSIS%202/2.46/nsis-2.46-strlen_8192.zip', 'C:\nsis-2.46-strlen_8192.zip')
(new-object System.Net.WebClient).DownloadFile('http://nsis.sourceforge.net/mediawiki/images/c/c9/Inetc.zip', 'C:\Inetc.zip')
(new-object System.Net.WebClient).DownloadFile('http://downloads.dlang.org/other/nsisunz-dll-1_0.zip', 'C:\nsisunz-dll-1_0.zip')
Wait-Process -id (Start-Process C:\nsis-2.46-setup.exe -ArgumentList "/S" -PassThru).id
$shell = new-object -com shell.application
$shell.NameSpace('C:\Program Files (x86)\NSIS').CopyHere($shell.NameSpace('C:\nsis-2.46-strlen_8192.zip').Items(), 0x614)
$shell.NameSpace('C:\Program Files (x86)\NSIS\Plugins').CopyHere($shell.NameSpace('C:\Inetc.zip\Plugins').Items(), 0x614)
$shell.NameSpace('C:\Program Files (x86)\NSIS\Plugins').CopyHere($shell.NameSpace('C:\nsisunz-dll-1_0.zip').Items(), 0x614)
del 'C:\nsis-2.46-setup.exe'
del 'C:\nsis-2.46-strlen_8192.zip'
del 'C:\Inetc.zip'
del 'C:\nsisunz-dll-1_0.zip'

Write-Host -foregroundcolor green 'Installing VirtualBox guest additions'
Wait-Process -id (Start-Process D:\cert\VBoxCertUtil.exe -ArgumentList "add-trusted-publisher","oracle-vbox.cer","--root","oracle-vbox.cer" -PassThru).id
Wait-Process -id (Start-Process D:\VBoxWindowsAdditions.exe -ArgumentList "/S" -PassThru).id

Write-Host -foregroundcolor green 'Configuring environment variables'
$oldPath=(Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
$newPath=$oldPath+';C:\Program Files (x86)\Git\cmd;C:\dm\bin;C:\Program Files (x86)\Microsoft Visual Studio 9.0\Common7\IDE'
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name VCDIR -Value 'C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC'
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name SDKDIR -Value 'C:\Program Files\Microsoft SDKs\Windows\v7.0'

Write-Host -foregroundcolor green 'OK'


del 'C:\setup.ps1'
