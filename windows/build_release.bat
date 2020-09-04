setlocal
echo on

if "%BRANCH%" == "" set BRANCH=stable

set HOST_DMD=%CD%\ldc2\bin\ldmd2.exe
set PATH=%CD%\ldc2\bin;%CD%\dm\bin;%PATH%

set LDC_VSDIR_FORCE=1
cd create_dmd_release

"%HOST_DMD%" -gf build_all.d common.d -version=NoVagrant || exit /B 1
build_all v%HOST_LDC_VERSION% %BRANCH% || exit /B 1
