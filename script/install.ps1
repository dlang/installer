# Build script for automatically setting up dmd & ldc on AppVeyor
function ResolveLatestDMD
{
    $version = $env:DVersion;
    if($version -eq "stable") {
        $latest = (Invoke-WebRequest "http://downloads.dlang.org/releases/LATEST").toString();
        $url = "http://downloads.dlang.org/releases/2.x/$($latest)/dmd.$($latest).windows.7z";
    }elseif($version -eq "beta") {
        $latest = (Invoke-WebRequest "http://downloads.dlang.org/pre-releases/LATEST").toString();
        $latestVersion = $latest.split("-")[0].split("~")[0];
        $url = "http://downloads.dlang.org/pre-releases/2.x/$($latestVersion)/dmd.$($latest).windows.7z";
    }elseif($version -eq "nightly") {
        $latest = (Invoke-WebRequest "https://nightlies.dlang.org/dmd-nightly/LATEST").toString().replace("`n","").replace("`r","");
        $url = "https://nightlies.dlang.org/dmd-$($latest)/dmd.master.windows.7z"
    }else {
        $url = "http://downloads.dlang.org/releases/2.x/$($version)/dmd.$($version).windows.7z";
    }
    $env:PATH += ";C:\dmd2\windows\bin;";
    return $url;
}
function ResolveLatestLDC
{
    $version = $env:DVersion;
    if($version -eq "stable") {
        $latest = (Invoke-WebRequest "https://ldc-developers.github.io/LATEST").toString().replace("`n","").replace("`r","");
        $url = "https://github.com/ldc-developers/ldc/releases/download/v$($latest)/ldc2-$($latest)-win64-msvc.zip";
    }elseif($version -eq "beta") {
        $latest = (Invoke-WebRequest "https://ldc-developers.github.io/LATEST_BETA").toString().replace("`n","").replace("`r","");
        $url = "https://github.com/ldc-developers/ldc/releases/download/v$($latest)/ldc2-$($latest)-win64-msvc.zip";
    } else {
        $latest = $version;
        $url = "https://github.com/ldc-developers/ldc/releases/download/v$($version)/ldc2-$($version)-win64-msvc.zip";
    }
    $env:PATH += ";C:\ldc2-$($latest)-win64-msvc\bin";
    $env:DC = "ldc2";
    return $url;
}
function SetUpDCompiler
{
    $env:toolchain = "msvc";
    if($env:DC -eq "dmd"){
      echo "downloading ...";
      $url = ResolveLatestDMD;
      echo $url;
      Invoke-WebRequest $url -OutFile "c:\dmd.7z";
      echo "finished.";
      pushd c:\\;
      7z x dmd.7z > $null;
      popd;
    }
    elseif($env:DC -eq "ldc"){
      echo "downloading ...";
      $url = ResolveLatestLDC;
      echo $url;
      Invoke-WebRequest $url -OutFile "c:\ldc.zip";
      echo "finished.";
      pushd c:\\;
      7z x ldc.zip > $null;
      popd;
    }
}
SetUpDCompiler

if($env:arch -eq "x86"){
    $env:compilersetupargs = "x86";
    $env:Darch = "x86";
    $env:DConf = "m32";
}elseif($env:arch -eq "x64"){
    $env:compilersetupargs = "amd64";
    $env:Darch = "x86_64";
    $env:DConf = "m64";
}
# This needs to be done more generically (currently only works on AppVeyor)
$env:compilersetup = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall";
