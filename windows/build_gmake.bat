@setlocal

set ROOT=%CD%
mkdir gnumake
cd gnumake

set GMAKE_URL=https://ftp.gnu.org/gnu/make/make-%GMAKE_VER%.tar.gz
appveyor DownloadFile %GMAKE_URL% -FileName make.tar.gz || exit /B 1

echo e968ce3c57ad39a593a92339e23eb148af6296b9f40aa453a9a9202c99d34436  make.tar.gz> sha256sums
sha256sum -c sha256sums || exit /B 1

7z x make.tar.gz -so | 7z x -si -ttar || exit /B 1
cd make-%GMAKE_VER%

call "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat"
call build_w32.bat || exit /B 1

cp WinRel\gnumake.exe ..\make.exe
cd ..

make.exe --version || exit /B 1

7z a %ROOT%\gmake-%GMAKE_VER%.zip make.exe
