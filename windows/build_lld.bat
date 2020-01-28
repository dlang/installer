@setlocal
@echo on

set ROOT=%CD%
mkdir "%ROOT%\artifacts"

REM Stop early if the artifact already exists
powershell -Command "Invoke-WebRequest downloads.dlang.org/other/lld-link-%LLVM_VER%.zip -OutFile %ROOT%\artifacts\lld-link-%LLVM_VER%.zip" && exit /B 0


call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" %ARCH%
cd %ROOT%

set LLVM_URL=http://releases.llvm.org/%LLVM_VER%
powershell -Command "Invoke-WebRequest %LLVM_URL%/lld-%LLVM_VER%.src.tar.xz -OutFile lld.src.tar.xz" || exit /B 1
powershell -Command "Invoke-WebRequest %LLVM_URL%/llvm-%LLVM_VER%.src.tar.xz -OutFile llvm.src.tar.xz" || exit /B 1

:: e.g. from git installation
dos2unix "%ROOT%\windows\build_lld.sha256sums"
sha256sum -c "%ROOT%\windows\build_lld.sha256sums" || exit /B 1

7z x "llvm.src.tar.xz" || exit /B 1
7z x "lld.src.tar.xz"  || exit /B 1

7z x "llvm.src.tar" || exit /B 1
7z x "lld.src.tar"  || exit /B 1

move "llvm-%LLVM_VER%.src" llvm
move "lld-%LLVM_VER%.src" llvm\tools\lld

set lld_build_dir=build-lld
if not exist "%lld_build_dir%\nul" md "%lld_build_dir%"
cd "%lld_build_dir%"

set CMAKE_OPT=-G "Visual Studio 15"
set CMAKE_OPT=%CMAKE_OPT% -DCMAKE_BUILD_TYPE=Release
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_TARGETS_TO_BUILD=X86
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_USE_CRT_DEBUG=MTd
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_USE_CRT_RELEASE=MT
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_USE_CRT_MINSIZEREL=MT
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_INCLUDE_DIRS="c:/projects/llvm/include"

cmake %CMAKE_OPT% ..\llvm || exit /B 1
devenv LLVM.sln /project lld /Build "MinSizeRel|Win32" || exit /B 1

cd MinSizeRel\bin
7z a "%ROOT%\artifacts\lld-link-%LLVM_VER%.zip" lld-link.exe
