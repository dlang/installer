@setlocal
@echo on

set ROOT=%CD%
mkdir "%ROOT%\artifacts"

set ARTIFACT=lld-link-%LLVM_VER%-seh.zip
if "%ARCH%" == "x64" set ARTIFACT=lld-link-%LLVM_VER%-seh-x64.zip
set ARTIFACTPATH=%ROOT%\artifacts\%ARTIFACT%

REM Stop early if the artifact already exists
powershell -Command "Invoke-WebRequest downloads.dlang.org/other/%ARTIFACT% -OutFile %ARTIFACTPATH%" && exit /B 0


call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" %ARCH%
cd %ROOT%
@echo on


:: LLVM releases are now done with github so need to match https://github.com/llvm/llvm-project/releases/download/llvmorg-14.0.0/lld-14.0.0.src.tar.xz

set LLVM_URL=https://github.com/llvm/llvm-project/releases/download/llvmorg-%LLVM_VER%
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

rem patch lld to not emit "No structured exception handler"
sed -e s/IMAGE_DLL_CHARACTERISTICS_NO_SEH/0/ llvm\tools\lld\COFF\Writer.cpp >Writer.tmp
move /Y Writer.tmp llvm\tools\lld\COFF\Writer.cpp

set CMAKE_OPT=%CMAKE_OPT% -DCMAKE_CXX_FLAGS="/DIMAGE_DLL_CHARACTERISTICS_NO_SEH=0"

set lld_build_dir=build-lld
if not exist "%lld_build_dir%\nul" md "%lld_build_dir%"
cd "%lld_build_dir%"

set CMAKE_OPT=-G "Visual Studio 15"
if "%ARCH%" == "x64" set CMAKE_OPT=-G "Visual Studio 15 Win64"

set CMAKE_OPT=%CMAKE_OPT% -DCMAKE_BUILD_TYPE=Release
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_TARGETS_TO_BUILD=X86
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_USE_CRT_DEBUG=MTd
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_USE_CRT_RELEASE=MT
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_USE_CRT_MINSIZEREL=MT
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_INCLUDE_DIRS="c:/projects/llvm/include"

set VSARCH=%ARCH%
if "%VSARCH%" == "x86" set VSARCH=Win32

cmake %CMAKE_OPT% ..\llvm || exit /B 1
devenv LLVM.sln /project lld /Build "MinSizeRel|%VSARCH%" || exit /B 1

cd MinSizeRel\bin
7z a "%ARTIFACTPATH%" lld-link.exe
