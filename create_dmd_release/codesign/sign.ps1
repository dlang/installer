$cert = $args[0]
$fingerprint = Get-Content -Path $args[1]
$pw = Get-Content -Path $args[2]
$file = $args[3]

# check whether binary is already signed
$sig = Get-AuthenticodeSignature "$file"
if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Thumbprint -eq "$fingerprint")
{
  Write-Output "Skipping already signed $file`n"
  exit
}

$key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
$sdkdir = (Get-ItemProperty -Path $key -Name KitsRoot10).KitsRoot10

# need an interactive logon to access the certificate store
# as sshd just creates a network logon for pubkey authenticated users
# also see https://github.com/PowerShell/Win32-OpenSSH/issues/996
$ps = new-object System.Diagnostics.Process
$ps.StartInfo.UserName = 'vagrant'
$ps.StartInfo.Password = ConvertTo-SecureString 'vagrant' -AsPlainText -Force
$ps.StartInfo.Filename = "$sdkdir\App Certification Kit\signtool.exe"
$ps.StartInfo.Arguments = "sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /f $cert /p $pw $file"
$ps.StartInfo.UseShellExecute = $False
$ps.StartInfo.RedirectStandardOutput = $True
$ps.StartInfo.RedirectStandardError = $True
$ps.start() | Out-Null
$ps.WaitForExit()
Write-Output $ps.StandardOutput.ReadToEnd()
if ($ps.ExitCode -ne 0)
{
  Write-Error $ps.StandardError.ReadToEnd()
}
