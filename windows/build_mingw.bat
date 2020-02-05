@setlocal

set ROOT=%CD%
mkdir "%ROOT%\artifacts"

set ARTIFACT=mingw-libs-%MINGW_VER%-2.zip
set ARTIFACTPATH=%ROOT%\artifacts\%ARTIFACT%

REM Stop early if the artifact already exists
powershell -Command "Invoke-WebRequest downloads.dlang.org/other/%ARTIFACT% -OutFile %ARTIFACTPATH%" && exit /B 0

set DMD_URL=http://downloads.dlang.org/releases/2.x/%D_VERSION%/dmd.%D_VERSION%.windows.7z
echo DMD_URL=%DMD_URL%
powershell -Command "Invoke-WebRequest %DMD_URL% -OutFile dmd2.7z" || exit /B 1
7z x dmd2.7z || exit /B 1
set PATH=%ROOT%\dmd2\windows\bin;%PATH%

set MINGW_URL=https://netix.dl.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v%MINGW_VER%.tar.bz2
set USER_AGENT=[Microsoft.PowerShell.Commands.PSUserAgent]::FireFox

powershell -Command "Invoke-WebRequest %MINGW_URL% -OutFile mingw-w64.tar.bz2 -UserAgent %User_Agent%"  || exit /B 1

:: e.g. from git installation
dos2unix "%ROOT%\windows\build_mingw.sha256sums"
sha256sum -c "%ROOT%\windows\build_mingw.sha256sums" || exit /B 1

7z x mingw-w64.tar.bz2 || exit /B 1
7z x mingw-w64.tar || exit /B 1

move mingw-w64-v%MINGW_VER% mingw-w64

call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x86_amd64
rem CWD might be changed by vcvars64.bat
cd %ROOT%\windows\mingw
dmd -run buildsdk.d x64 %ROOT%\mingw-w64 dmd2\windows\lib64\mingw || exit /B 1

call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x86
cd %ROOT%\windows\mingw
dmd -run buildsdk.d x86 %ROOT%\mingw-w64 dmd2\windows\lib32mscoff\mingw || exit /B 1

7z a "%ARTIFACTPATH%" dmd2\windows
