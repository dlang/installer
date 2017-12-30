@setlocal
call "c:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars32.bat"
git clone --depth 1 --branch %BRANCH% https://github.com/llvm-mirror/llvm.git llvm || exit /B 1
git clone --depth 1 --branch %BRANCH% https://github.com/llvm-mirror/lld.git llvm\tools\lld || exit /B 1

set lld_build_dir=build-lld
if not exist %lld_build_dir%\nul md %lld_build_dir%
cd %lld_build_dir%

set CMAKE_OPT=-G "Visual Studio 15"
set CMAKE_OPT=%CMAKE_OPT% -DCMAKE_BUILD_TYPE=Release
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_TARGETS_TO_BUILD=X86 
set CMAKE_OPT=%CMAKE_OPT% -DLLVM_INCLUDE_DIRS="c:/projects/llvm/include"

cmake %CMAKE_OPT% ..\llvm || exit /B 1
devenv LLVM.sln /project lld /Build "MinSizeRel|Win32" || exit /B 1

if not exist ..\bin\nul md ..\bin
copy MinSizeRel\bin\lld-link.exe ..\bin
cd ..
