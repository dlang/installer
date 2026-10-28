@setlocal
@echo on

:: Also See: https://www.appveyor.com/docs/build-environment
SET ROOT=%CD%

mkdir "%ROOT%\artifacts"
set ARTIFACT=libcurl-%CURL_VER%-WinSSL-zlib-x86-x64.zip

REM Stop early if the artifact already exists
powershell -Command "Invoke-WebRequest downloads.dlang.org/other/%ARTIFACT% -OutFile %ROOT%\artifacts\%ARTIFACT%" && exit /B 0

:: --------------------------------------------------------------------
:: Download and Unpack

powershell -Command "Invoke-WebRequest https://github.com/madler/zlib/releases/download/v%ZLIB_VER%/zlib-%ZLIB_VER%.tar.xz -OutFile zlib.tar.xz" || exit /B 1
powershell -Command "Invoke-WebRequest https://curl.se/download/curl-%CURL_VER%.tar.xz -OutFile curl.tar.xz" || exit /B 1
powershell -Command "Invoke-WebRequest http://ftp.digitalmars.com/bup.zip -OutFile bup.zip" || exit /B 1

:: e.g. from git installation
dos2unix "%ROOT%\windows\build_curl.sha256sums"
sha256sum -c "%ROOT%\windows\build_curl.sha256sums" || exit /B 1

7z x zlib.tar.xz || exit /B 1
7z x zlib.tar || exit /B 1
7z x curl.tar.xz || exit /B 1
7z x curl.tar || exit /B 1
7z x bup.zip || exit /B 1

move zlib-%ZLIB_VER% zlib
move curl-%CURL_VER% curl

set CMAKE_COMMON=-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded
set ZLIB_FLAGS=-DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_TESTING=OFF
set CURL_FLAGS=-DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_CURL_EXE=OFF -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF ^
 -DBUILD_LIBCURL_DOCS=OFF -DBUILD_MISC_DOCS=OFF -DENABLE_CURL_MANUAL=OFF -DCURL_USE_PKGCONFIG=OFF ^
 -DCURL_USE_SCHANNEL=ON -DCURL_ZLIB=ON -DCURL_BROTLI=OFF -DCURL_ZSTD=OFF -DUSE_NGHTTP2=OFF ^
 -DUSE_LIBIDN2=OFF -DCURL_USE_LIBPSL=OFF -DCURL_USE_LIBSSH2=OFF -DENABLE_IPV6=ON

:: --------------------------------------------------------------------
:: Build DLLs and import libs

call :build x64 64 || exit /B 1
call :build x86 32 || exit /B 1

mkdir dmd2\windows\bin64 dmd2\windows\lib64
copy build-curl64\lib\libcurl.dll dmd2\windows\bin64 || exit /B 1
copy build-curl64\lib\libcurl_imp.lib dmd2\windows\lib64\curl.lib || exit /B 1

mkdir dmd2\windows\bin dmd2\windows\lib dmd2\windows\lib32mscoff
copy build-curl32\lib\libcurl.dll dmd2\windows\bin || exit /B 1
dm\bin\implib /system dmd2\windows\lib\curl.lib build-curl32\lib\libcurl.dll || exit /B 1
copy build-curl32\lib\libcurl_imp.lib dmd2\windows\lib32mscoff\curl.lib || exit /B 1

:: --------------------------------------------------------------------
:: Zip it up

7z a %ROOT%\artifacts\%ARTIFACT% dmd2 || exit /B 1
exit /B 0

:build
setlocal
call "%VSINSTALLDIR%\Common7\Tools\VsDevCmd.bat" -arch=%1
@echo on
cd %ROOT%

cmake -S zlib -B build-zlib%2 %CMAKE_COMMON% %ZLIB_FLAGS% "-DCMAKE_INSTALL_PREFIX=%ROOT%\zlib%2" || exit /B 1
cmake --build build-zlib%2 --target install || exit /B 1
cmake -S curl -B build-curl%2 %CMAKE_COMMON% %CURL_FLAGS% "-DZLIB_INCLUDE_DIR=%ROOT%\zlib%2\include" "-DZLIB_LIBRARY=%ROOT%\zlib%2\lib\zs.lib" || exit /B 1
cmake --build build-curl%2 || exit /B 1
exit /B 0
