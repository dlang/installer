@echo off
echo Note:
echo - This bootstrapper requires an active internet connection.
echo - On Windows, this only bootstraps the 32-bit compiler, std lib and rdmd
echo   because that's sufficient to allow anything else to be built using
echo   a more practical D-based script.
echo - This script can be safely run from any directory.
echo - This bootstrap-dmd.bat is the ONLY file required to bootstrap Win32 DMD.
echo.

rem MAINTAINERS:
rem   In all the sections that generate text files (via redirected echo),
rem   please make sure:
rem   - Each line starts with "echo." (note the period)
rem   - The first line uses overwrite (">"), and the rest use appending (">>")
rem   - All % are escaped as %%
rem   - All &, |, > and < are escaped as ^&, ^|, ^> and ^<

if "%1" == "" (
    echo Usage: bootstrap-dmd branch_name
    echo Ex:    bootstrap-dmd 2.063
    exit /B 1
)

set PATH_BAK=%PATH%

rem Configuration
set DMD_BRANCH=%1
set WORK_DIR=bootstrap-dmd-%DMD_BRANCH%
set SCRAP_DIR=%WORK_DIR%\scrap
set DMC_URL=http://ftp.digitalmars.com/Digital_Mars_C++/Patch/dm856c.zip
set DMD_GITHUB=https://github.com/D-Programming-Language/dmd
set DMD_DRUNTIME_GITHUB=https://github.com/D-Programming-Language/druntime
set DMD_PHOBOS_GITHUB=https://github.com/D-Programming-Language/phobos
set DMD_TOOLS_GITHUB=https://github.com/D-Programming-Language/tools
set UNZIP_URL=http://semitwist.com/download/app/unz600xn.exe

rem Internal configuration
set "CD="
set ABS_BASE=%CD%\
set DLOAD_SCRIPT=%SCRAP_DIR%\download.vbs
set DLOAD_CMD=cscript //Nologo %DLOAD_SCRIPT%
set FAKE_GIT_SCRIPT=%SCRAP_DIR%\fake-git.bat
set REAL_GIT_SCRIPT=%SCRAP_DIR%\real-git.bat
set UNZIP_DIR=%SCRAP_DIR%\unzip
set UNZIP_CMD=%UNZIP_DIR%\unzip.exe -q
set DM_BIN=%WORK_DIR%\dm\bin
set DMD_BIN=%WORK_DIR%\dmd\bin32
set DMD_LIB=%WORK_DIR%\dmd\lib32

rem Fresh start
rmdir /S /Q "%WORK_DIR%" 2> NUL
if exist "%WORK_DIR%" (
    echo ERROR: Failed to remove the old work directory:
    echo %ABS_BASE%%WORK_DIR%
    echo.
    echo A process may still holding an open handle within the directory.
    echo Either delete the directory manually or try again later.
    exit /B 1
)
mkdir %WORK_DIR% 2> NUL
mkdir %SCRAP_DIR% 2> NUL
mkdir %UNZIP_DIR% 2> NUL

rem Generate downloader script
rem Windows has no built-in wget or curl, so generate a VBS script to do it.
rem -------------------------------------------------------------------------
echo.Option Explicit                                                    >  %DLOAD_SCRIPT%
echo.Dim args, http, fileSystem, adoStream, url, target, status         >> %DLOAD_SCRIPT%
echo.                                                                   >> %DLOAD_SCRIPT%
echo.Set args = Wscript.Arguments                                       >> %DLOAD_SCRIPT%
echo.Set http = CreateObject("WinHttp.WinHttpRequest.5.1")              >> %DLOAD_SCRIPT%
echo.url = args(0)                                                      >> %DLOAD_SCRIPT%
echo.target = args(1)                                                   >> %DLOAD_SCRIPT%
echo.WScript.Echo "Getting '" ^& target ^& "' from '" ^& url ^& "'..."  >> %DLOAD_SCRIPT%
echo.                                                                   >> %DLOAD_SCRIPT%
echo.http.Open "GET", url, False                                        >> %DLOAD_SCRIPT%
echo.http.Send                                                          >> %DLOAD_SCRIPT%
echo.status = http.Status                                               >> %DLOAD_SCRIPT%
echo.                                                                   >> %DLOAD_SCRIPT%
echo.If status ^<^> 200 Then                                            >> %DLOAD_SCRIPT%
echo.    WScript.Echo "FAILED to download: HTTP Status " ^& status      >> %DLOAD_SCRIPT%
echo.    WScript.Quit 1                                                 >> %DLOAD_SCRIPT%
echo.End If                                                             >> %DLOAD_SCRIPT%
echo.                                                                   >> %DLOAD_SCRIPT%
echo.Set adoStream = CreateObject("ADODB.Stream")                       >> %DLOAD_SCRIPT%
echo.adoStream.Open                                                     >> %DLOAD_SCRIPT%
echo.adoStream.Type = 1                                                 >> %DLOAD_SCRIPT%
echo.adoStream.Write http.ResponseBody                                  >> %DLOAD_SCRIPT%
echo.adoStream.Position = 0                                             >> %DLOAD_SCRIPT%
echo.                                                                   >> %DLOAD_SCRIPT%
echo.Set fileSystem = CreateObject("Scripting.FileSystemObject")        >> %DLOAD_SCRIPT%
echo.If fileSystem.FileExists(target) Then fileSystem.DeleteFile target >> %DLOAD_SCRIPT%
echo.adoStream.SaveToFile target                                        >> %DLOAD_SCRIPT%
echo.adoStream.Close                                                    >> %DLOAD_SCRIPT%
rem -------------------------------------------------------------------------

rem Generate script to fake Git
rem (There's a way to do functions in batch, but I couldn't get it to work.)
rem MAINTAINERS: In all the sections (like this) that generate text files,
rem              make sure each line starts with "echo." (note the period)
rem              and that all "%" are escaped as "%%".
rem -------------------------------------------------------------------------
echo.^@echo off                                                         >  %FAKE_GIT_SCRIPT%
echo.rem This script is only intended to be run from bootstrap-dmd.bat  >> %FAKE_GIT_SCRIPT%
echo.                                                                   >> %FAKE_GIT_SCRIPT%
echo.%%DLOAD_CMD%% %%1/archive/%%DMD_BRANCH%%.zip %%SCRAP_DIR%%\%%2.zip >> %FAKE_GIT_SCRIPT%
echo.echo Extracting %%~3...                                            >> %FAKE_GIT_SCRIPT%
echo.%%UNZIP_CMD%% %%SCRAP_DIR%%\%%2.zip -d %%WORK_DIR%%                >> %FAKE_GIT_SCRIPT%
echo.rename %%WORK_DIR%%\%%2-%%DMD_BRANCH%% %%2                         >> %FAKE_GIT_SCRIPT%
rem -------------------------------------------------------------------------

rem Generate script to run real Git
rem -------------------------------------------------------------------------
echo.^@echo off                                                         >  %REAL_GIT_SCRIPT%
echo.rem This script is only intended to be run from bootstrap-dmd.bat  >> %REAL_GIT_SCRIPT%
echo.                                                                   >> %REAL_GIT_SCRIPT%
echo.pushd .                                                            >> %REAL_GIT_SCRIPT%
echo.cd %%WORK_DIR%%                                                    >> %REAL_GIT_SCRIPT%
echo.call git clone --depth 1 --branch %%DMD_BRANCH%% %%1.git %%2       >> %REAL_GIT_SCRIPT%
echo.popd                                                               >> %REAL_GIT_SCRIPT%
rem -------------------------------------------------------------------------

rem Detect whether Git is available
call gitsssssssa --help > NUL 2> NUL
if errorlevel 1 (
    echo No Git detected, using fallback approach.
    set GIT_CMD=%FAKE_GIT_SCRIPT%
) else (
    echo Detected Git, using it.
    set GIT_CMD=%REAL_GIT_SCRIPT%
)

rem Get unzip tool
%DLOAD_CMD% %UNZIP_URL% %UNZIP_DIR%\unzip-archive.exe
pushd %UNZIP_DIR%
    unzip-archive.exe
popd

rem Get DMC
%DLOAD_CMD% %DMC_URL% %SCRAP_DIR%\dmc.zip
echo Extracting DMC...
%UNZIP_CMD% %SCRAP_DIR%\dmc.zip -d %WORK_DIR%

rem Get sources from GitHub
call %GIT_CMD% %DMD_GITHUB%           dmd       "DMD Sources"
call %GIT_CMD% %DMD_DRUNTIME_GITHUB%  druntime  "Druntime Sources"
call %GIT_CMD% %DMD_PHOBOS_GITHUB%    phobos    "Phobos Sources"
call %GIT_CMD% %DMD_TOOLS_GITHUB%     tools     "DMD Tools Sources"

rem Build DMD
set PATH=%ABS_BASE%%DM_BIN%;%PATH%
pushd .
    cd %WORK_DIR%\dmd\src
    make release -f win32.mak
popd
mkdir %DMD_BIN%
mkdir %DMD_LIB%
copy %WORK_DIR%\dmd\src\dmd.exe %DMD_BIN%

rem Copy over files from DMC
copy %DM_BIN%\link.exe %DMD_BIN%
copy %DM_BIN%\make.exe %DMD_BIN%
copy %DM_BIN%\lib.exe  %DMD_BIN%
copy %DM_BIN%\..\lib\*.lib %DMD_LIB%

rem Generate sc.ini
rem -------------------------------------------------------------------------
echo.[Environment]                                                   >  %DMD_BIN%\sc.ini
echo.LIB="%%@P%%\..\lib32"                                           >> %DMD_BIN%\sc.ini
echo.DFLAGS="-I%%@P%%\..\..\phobos" "-I%%@P%%\..\..\druntime\import" >> %DMD_BIN%\sc.ini
echo.LINKCMD=%%@P%%\link.exe                                         >> %DMD_BIN%\sc.ini
rem -------------------------------------------------------------------------

rem Build Druntime
set PATH=%ABS_BASE%%DMD_BIN%;%PATH%
pushd .
    cd %WORK_DIR%\druntime
    make -f win32.mak
popd

rem Build Phobos
pushd .
    cd %WORK_DIR%\phobos
    make -f win32.mak
popd
copy %WORK_DIR%\phobos\phobos.lib %DMD_LIB%

rem Build RDMD
pushd .
    cd %WORK_DIR%\tools
    make rdmd.exe -f win32.mak
popd
copy %WORK_DIR%\tools\rdmd.exe %DMD_BIN%

rem Sanity Check
if not exist "%DMD_BIN%\rdmd.exe" (
    echo.
    echo ERROR: The bootstrapping process did not complete successfully.
    exit /B 1
)

rem Show success message
echo.
echo The bootstrapped Win32 DMD is now available in %WORK_DIR%
echo.
echo The full path to the bootstrapped binaries is:
echo %ABS_BASE%%DMD_BIN%
echo.
echo If you wish to use this DMD permanently, you should add the bin directory
echo above to your system's PATH (search "setting Windows PATH environment" for
echo instructions) and then open a new command prompt.
echo.
echo For your convenience, this bootstrapped DMD, plus DMC, have been added to
echo your current command session's PATH. If you wish, you can undo the change
echo by entering:
echo     set PATH=%%PATH_BAK%%
