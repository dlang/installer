/+++
Prerequisites to Compile:
-------------------------
- Working D compiler

Prerequisites to Run:
---------------------
- Git
- Posix: Working gcc toolchain, including GNU make which is not installed on
  FreeBSD by default. On OSX, you can install the gcc toolchain through Xcode.
- Windows: Working DMC and MSVC toolchains. The default make must be DM make.
  Also, this environment variable must be set:
    VSINSTALLDIR:  Visual C directory
  Examples:
    set VSINSTALLDIR="C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\"
- Windows: A version of OPTLINK with the /LA[RGEADDRESSAWARE] flag:
    <https://github.com/DigitalMars/optlink/commit/475bc5c1fa28eaf899ba4ac1dcfe2ab415db16c6>
- Windows: Microsoft's HTML Help Workshop on the PATH.

Typical Usage:
--------------
0. Obtain/install all prerequisites above.

1. (An unfortunately necessary step:) Download this file:
<http://semitwist.com/download/app/dmd-localextras.7z>
This contains the handful of files not under version control which are needed
by DMD. These are in directories named 'localextras-[os]' which match the
directory structure of DMD. Extract that file, and if necessary, update any
of the files to the latest versions, or add any new files as desired.

2. On 64-bit multilib versions of each supported OS (Windows, OSX, Linux, and
FreeBSD), genrate the platform-specific releases by running this (from
whatever directory you want the resulting archives placed):

$ [path-to]/create_dmd_release v2.064 --extras=[path-to]/localextras-[os]

Optionally substitute "v2.064" with either "master" or the git tag name of the
desired release (must be at least "v2.064"). For beta releases, you can use a
branch name like "2.064".

If a working multilib system is any trouble, you can also build 32-bit and
64-bit versions separately using the --only-32 and --only-64 flags.

3. Distribute all the .zip files.

Extra notes:
------------
This tool keeps a deliberately strong separation between each of the main stages:

1. Clone   (from GitHub, into a temp dir)
2. Build   (compile everything, including docs, within the temp dir)
3. Package (generate an OS-specific zip)
+/

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.getopt;
import std.path;
import std.process;
import std.regex;
import std.stdio;
import std.string;
import std.typetuple;
import common;
version(Posix)
    import core.sys.posix.sys.stat;

immutable releaseBitSuffix32 = "-32"; // Ex: "dmd.v2.064.linux-32.zip"
immutable releaseBitSuffix64 = "-64";

version(Windows)
{
    // Cannot start with a period or MS's HTML Help Workshop will fail
    immutable defaultWorkDirName = "create_dmd_release";

    immutable makefile      = "win32.mak";
    immutable makefile64    = "win64.mak";
    immutable exe           = ".exe";
    immutable lib           = ".lib";
    immutable obj           = ".obj";
    immutable dll           = ".dll";
    immutable libPhobos32   = "phobos";
    immutable libPhobos64   = "phobos64";
    immutable build64BitTools = false;

    // Building Win64 druntime/phobos relies on an existing DMD, but there's no
    // official Win64 build/makefile of DMD. This is a hack to work around that.
    immutable lib64RequiresDmd32 = true;

    immutable osDirName     = "windows";
    immutable make          = "make";
    immutable suffix32      = "";   // bin/lib  TODO: adapt scripts to use 32
    immutable suffix64      = "64"; // bin64/lib64
}
else version(Posix)
{
    immutable defaultWorkDirName = ".create_dmd_release";
    immutable makefile      = "posix.mak";
    immutable makefile64    = "posix.mak";
    immutable exe           = "";
    immutable lib           = ".a";
    immutable obj           = ".o";
    immutable libPhobos32   = "libphobos2";
    immutable libPhobos64   = "libphobos2";
    immutable build64BitTools    = true;
    immutable lib64RequiresDmd32 = false;

    version(FreeBSD)
        immutable osDirName = "freebsd";
    else version(linux)
        immutable osDirName = "linux";
    else version(OSX)
        immutable osDirName = "osx";
    else
        static assert(false, "Unsupported system");

    version(FreeBSD)
        immutable make = "gmake";
    else
        immutable make = "make";

    version(OSX)
    {
        // TODO: adapt scripts to use 32/64
        immutable suffix32      = ""; // bin/lib
        immutable suffix64      = ""; // bin/lib
        immutable dll           = ".dylib";
    }
    else
    {
        immutable suffix32      = "32"; // bin32/lib32
        immutable suffix64      = "64"; // bin64/lib64
        immutable dll           = ".so";
    }
}
else
    static assert(false, "Unsupported system");

/// Fatal error message to exit cleanly with.
class Fail : Exception
{
    this(string msg) { super(msg); }
}

/// Minor convenience func
void fail(string msg)
{
    throw new Fail(msg);
}

enum Bits { bits32, bits64 }
string toString(Bits bits)
{
    return bits == Bits.bits32? "32-bit" : "64-bit";
}

bool skipDocs;
bool do32Bit;
bool do64Bit;
bool codesign;

// These are absolute and do NOT contain a trailing slash:
string defaultWorkDir;
string cloneDir;
string origDir;
string releaseDir;
string releaseBin32Dir;
string releaseLib32Dir;
string releaseBin64Dir;
string releaseLib64Dir;
string osDir;
string allExtrasDir;
string osExtrasDir;
string customExtrasDir;
string hostDMD;

int main(string[] args)
{
    defaultWorkDir = buildPath(tempDir(), defaultWorkDirName);

    bool help;
    bool clean;

    getopt(
        args,
        std.getopt.config.caseSensitive,
        "use-clone",    &cloneDir,
        "skip-docs",    &skipDocs,
        "clean",        &clean,
        "extras",       &customExtrasDir,
        "host-dmd",     &hostDMD,
        "only-32",      &do32Bit,
        "only-64",      &do64Bit,
        "codesign",     &codesign,
    );

    if(args.length < 2)
    {
        fatal("Missing arguments.");
        return 1;
    }

    // Handle command line args
    if(args.length != 2 && !clean)
    {
        fatal("Missing TAG_OR_BRANCH.");
        return 1;
    }

    if(do32Bit && do64Bit)
    {
        fatal("--only-32 and --only-64 cannot be used together.");
        return 1;
    }

    version(OSX)
    {
        if(do32Bit || do64Bit)
        {
            info("WARNING: Using --only-32 and --only-64: Universal binaries will not be created.");
            return 1;
        }
    }

    if(!do32Bit && !do64Bit)
        do32Bit = do64Bit = true;

    if(customExtrasDir == "")
    {
        fatal("--extras=path is required.");
        return 1;
    }
    else
        customExtrasDir = customExtrasDir.absolutePath().chomp("\\").chomp("/");

    if(hostDMD == "")
    {
        fatal("--host-dmd=path is required.");
        return 1;
    }
    else
        hostDMD = hostDMD.absolutePath();

    // Do the work
    try
    {
        if(clean)
        {
            removeDir(defaultWorkDir);
            return 0;
        }

        string branch = args[1];
        init(branch);

        cleanAll(branch);
        buildAll(branch);
        createRelease(branch);
        createZip(branch);

        info("Done!");
    }
    catch(Fail e)
    {
        // Just show the message, omit the stack trace.
        fatal(e.msg);
        return 1;
    }

    return 0;
}

void init(string branch)
{
    auto saveDir = getcwd();
    scope(exit) changeDir(saveDir);

    // Setup directory paths
    origDir = getcwd();
    auto dirBitSuffix = releaseBitSuffix(do32Bit, do64Bit);
    releaseDir = origDir ~ `/dmd.` ~ branch ~ "." ~ osDirName ~ dirBitSuffix;

    if(cloneDir == "")
        cloneDir = defaultWorkDir;
    cloneDir = absolutePath(cloneDir);

    osDir = releaseDir ~ "/dmd2/" ~ osDirName;
    releaseBin32Dir = osDir ~ "/bin" ~ suffix32;
    releaseLib32Dir = osDir ~ "/lib" ~ suffix32;
    releaseBin64Dir = osDir ~ "/bin" ~ suffix64;
    releaseLib64Dir = osDir ~ "/lib" ~ suffix64;
    allExtrasDir = cloneDir ~ "/installer/create_dmd_release/extras/all";
    osExtrasDir  = cloneDir ~ "/installer/create_dmd_release/extras/" ~ osDirName;
}

void cleanAll(string branch)
{
    if(do32Bit)
        cleanAll(Bits.bits32, branch);

    if(do64Bit)
        cleanAll(Bits.bits64, branch);
}

void cleanAll(Bits bits, string branch)
{
    auto saveDir = getcwd();
    scope(exit) changeDir(saveDir);

    auto targetMakefile = bits == Bits.bits32? makefile : makefile64;
    auto bitsStr        = bits == Bits.bits32? "32" : "64";
    auto bitsDisplay = toString(bits);
    auto makeModel = " MODEL="~bitsStr;
    auto hostDMDEnv = " HOST_DC="~hostDMD~" HOST_DMD="~hostDMD;
    auto latest = " LATEST="~branch;

    // common make arguments
    auto makecmd = make~makeModel~hostDMDEnv~latest~" -f"~targetMakefile;

    info("Cleaning DMD "~bitsDisplay);
    changeDir(cloneDir~"/dmd/src");
    run(makecmd~" clean");

    info("Cleaning Druntime "~bitsDisplay);
    changeDir(cloneDir~"/druntime");
    run(makecmd~" clean");

    info("Cleaning Phobos "~bitsDisplay);
    changeDir(cloneDir~"/phobos");
    version(Windows)
        removeDir(cloneDir~"/phobos/generated");

    // Windows is 32-bit only currently
    if (targetMakefile != "win64.mak")
    {
        info("Cleaning Tools "~bitsDisplay);
        changeDir(cloneDir~"/tools");
        run(makecmd~" clean");
    }
}

void buildAll(string branch)
{
    if(do32Bit)
        buildAll(Bits.bits32, branch);

    if(do64Bit)
    {
        if(!do32Bit && lib64RequiresDmd32)
            buildAll(Bits.bits32, branch, true);

        buildAll(Bits.bits64, branch);
    }
}

/// dmdOnly is part of the lib64RequiresDmd32 hack.
void buildAll(Bits bits, string branch, bool dmdOnly=false)
{
    auto saveDir = getcwd();
    scope(exit) changeDir(saveDir);

    auto msvcVarsX64 = "";
    auto msvcVarsX86 = "";
    auto msvcVars = "";
    auto msvcEnv = "";
    version(Windows)
    {
        bool hostIsLDC = hostDMD.endsWith("ldmd2") || hostDMD.endsWith("ldmd2.exe");
        if(bits == Bits.bits64)
        {
            // Just overwrite any logic in makefiles and leave setup to vcvarsall.bat
            msvcEnv = ` "VCDIR=" "SDKDIR=" "CC=cl" "CC32=cl" "LD=link" "AR=lib"`;
        }
        else
        {
            // use lib.exe from dmc distribution
            auto dmcPath = environment["PATH"].split(';').find!((p, f) => buildPath(p, f).exists)("dmc.exe").front;
            msvcEnv = " " ~ quote("AR="~dmcPath~"/lib");
        }
        if(bits == Bits.bits64 || hostIsLDC)
        {
            // ensure LDC auto-configures proper environment
            auto ldcVars = hostIsLDC ? "set LDC_VSDIR_FORCE=1 && " : null;
            // Setup MSVC environment for x64/x86 native builds
            auto vcVars = quote(environment["VSINSTALLDIR"] ~ `VC\Auxiliary\Build\vcvarsall.bat`);
            msvcVarsX64 = vcVars~" x64 && " ~ ldcVars;
            msvcVarsX86 = vcVars~" x86 && " ~ ldcVars;
            msvcVars = bits == Bits.bits64 ? msvcVarsX64 : msvcVarsX86;
        }
    }

    auto targetMakefile = bits == Bits.bits32? makefile    : makefile64;
    auto libPhobos      = bits == Bits.bits32? libPhobos32 : libPhobos64;
    auto bitsStr = bits == Bits.bits32? "32" : "64";
    auto bitsDisplay = toString(bits);
    auto makeModel = " MODEL="~bitsStr;
    version (Windows)
    {
        auto jobs = "";
        auto dmdEnv = ` DMD=..\dmd\generated\`~osDirName~`\release\32\dmd`~exe;
        enum dmdConf = "sc.ini";
    }
    else
    {
        auto jobs = " -j4";
        auto dmdEnv = " DMD=../dmd/generated/"~osDirName~"/release/"~bitsStr~"/dmd"~exe;
        enum dmdConf = "dmd.conf";
    }
    auto hostDMDEnv = " HOST_DC="~hostDMD~" HOST_DMD="~hostDMD;
    auto isRelease = " ENABLE_RELEASE=1";
    auto latest = " LATEST="~branch;
    // PIC libraries on amd64 for PIE-by-default distributions, see Bugzilla 16794
    version (linux)
        auto pic = bits == Bits.bits64 ? " PIC=1" : "";
    else
        auto pic = "";

    // common make arguments
    auto makecmd = make~jobs~makeModel~dmdEnv~hostDMDEnv~isRelease~latest~" -f "~targetMakefile;

    info("Building DMD "~bitsDisplay);
    changeDir(cloneDir~"/dmd/src");
    version (Windows)
        run(msvcVars~makecmd~" dmd");
    else
        run(makecmd);

    // Generate temporary sc.ini
    version(Windows)
    {
        std.file.write(cloneDir~`\dmd\generated\`~osDirName~`\release\`~bitsStr~`\sc.ini`, (`
            [Environment]
            LIB=%@P%\..\..\..\..\..\phobos;`~customExtrasDir~`\dmd2\windows\lib;%@P%\..\..\..\..\..\installer\create_dmd_release\extras\windows\dmd2\windows\lib
            DFLAGS="-I%@P%\..\..\..\..\..\phobos" "-I%@P%\..\..\..\..\..\druntime\import"
            [Environment32]
            LINKCMD=%@P%\optlink.exe
        `).outdent().strip());
    }

    // Copy OPTLINK to same directory as the sc.ini we want it to read
    version(Windows)
        copyFile(customExtrasDir~"/dmd2/windows/bin/optlink.exe", cloneDir~"/dmd/generated/"~osDirName~"/release/"~bitsStr~"/optlink.exe");

    if(dmdOnly)
        return;

    string makeTargetDruntime;
    version(Windows)
        if (bits == Bits.bits32)
            makeTargetDruntime = " target implibs";

    info("Building Druntime "~bitsDisplay);
    changeDir(cloneDir~"/druntime");
    run(msvcVars~makecmd~pic~msvcEnv~makeTargetDruntime);
    removeFiles(cloneDir~"/druntime", "*{"~obj~"}", SpanMode.depth,
        file => !file.baseName.startsWith("minit"));

    info("Building Phobos "~bitsDisplay);
    changeDir(cloneDir~"/phobos");
    run(msvcVars~makecmd~pic~msvcEnv);

    version(OSX) if(bits == Bits.bits64)
    {
        info("Building Phobos Universal Binary");
        changeDir(cloneDir~"/phobos");
        run(makecmd~" libphobos2.a");
    }
    removeFiles(cloneDir~"/phobos", "*{"~obj~"}", SpanMode.depth);

    version (Windows) if (bits == Bits.bits64)
    {
        info("Building Druntime 32mscoff");
        changeDir(cloneDir~"/druntime");
        run(msvcVarsX86~makecmd~msvcEnv~" druntime32mscoff");
        removeFiles(cloneDir~"/druntime", "*{"~obj~"}", SpanMode.depth,
                    file => !file.baseName.startsWith("minit"));

        info("Building Phobos 32mscoff");
        changeDir(cloneDir~"/phobos");
        run(msvcVarsX86~makecmd~msvcEnv~" phobos32mscoff");
        removeFiles(cloneDir~"/phobos", "*{"~obj~"}", SpanMode.depth);
    }

    // Build docs
    if(!skipDocs)
    {
        version (linux)
        {
            if (bits == Bits.bits32)
            {
                changeDir(cloneDir~"/dlang.org");
                run(makecmd~" DOC_OUTPUT_DIR="~origDir~"/docs release");
                // copy generated man pages to docs/man which gets copied to all other platforms
                copyDir(cloneDir~"/dmd/generated/docs/man", origDir~"/docs/man");
            }
        }
    }

    if(build64BitTools || bits == Bits.bits32)
    {
        info("Building Tools "~bitsDisplay);
        changeDir(cloneDir~"/tools");
        run(makecmd~" rdmd");
        run(makecmd~" ddemangle");
        run(makecmd~" dustmite");

        removeFiles(cloneDir~"/tools", "*.{"~obj~"}", SpanMode.depth);
    }

    bool buildDub = true; // build64BitTools || bits == Bits.bits32;
    if(buildDub)
    {
        // build dub with stable (host) compiler, b/c it breaks
        // too easily with the latest compiler, e.g. for nightlies
        info("Building Dub "~bitsDisplay);
        changeDir(cloneDir~"/dub");

        if (exists("build.d"))
        {
            // v1.20+
            version (Windows)
                run(msvcVars~"SET DMD="~hostDMD~" && "~hostDMD~" -m"~bitsStr~" -run build.d -O -w -m"~bitsStr);
            else
                run("DMD="~hostDMD~" "~hostDMD~" -run build.d -O -w -m"~bitsStr);
        }
        else
        {
            version (Windows)
                run(msvcVars~"SET DC="~hostDMD~" && build.cmd -m"~bitsStr); // TODO: replace DC with DMD
            else
                run("DMD="~hostDMD~" ./build.sh -m"~bitsStr);
        }
        rename(cloneDir~"/dub/bin/dub"~exe, cloneDir~"/dub/bin/dub"~bitsStr~exe);
    }
}

/// This doesn't use "make install" in order to avoid problems from
/// differences between 'posix.mak' and 'win*.mak'.
void createRelease(string branch)
{
    info("Generating release directory");

    removeDir(releaseDir);

    // Copy extras, if any
    if(customExtrasDir != "")
        copyDir(customExtrasDir, releaseDir);

    if(exists(allExtrasDir)) copyDir(allExtrasDir, releaseDir);
    if(exists( osExtrasDir)) copyDir( osExtrasDir, releaseDir);

    // Copy sources
    copyDirVersioned(cloneDir~"/dmd/src",  releaseDir~"/dmd2/src/dmd");
    copyDirVersioned(cloneDir~"/druntime", releaseDir~"/dmd2/src/druntime");
    copyDirVersioned(cloneDir~"/phobos",   releaseDir~"/dmd2/src/phobos");
    copyDirVersioned(cloneDir~"/dmd/ini/" ~ osDirName,  releaseDir~"/dmd2/" ~ osDirName);

    // druntime/doc doesn't get generated on Windows with --only-64, I don't know why.
    if(exists(cloneDir~"/druntime/doc"))
        copyDir(cloneDir~"/druntime/doc", releaseDir~"/dmd2/src/druntime/doc");
    copyDir(cloneDir~"/druntime/import", releaseDir~"/dmd2/src/druntime/import");
    copyFile(cloneDir~"/dmd/VERSION",    releaseDir~"/dmd2/src/VERSION");

    // Copy documentation
    if (!skipDocs)
    {
        auto dlangFilter = (string a) =>
            !a.startsWith("images/original/") &&
            !a.startsWith("chm/") &&
            ( a.endsWith(".html") || a.startsWith("css/", "images/", "js/") );
        // copy docs from linux build
        copyDir(origDir~"/docs", releaseDir~"/dmd2/html/d", a => dlangFilter(a));
        copyDirVersioned(cloneDir~"/dmd/samples",  releaseDir~"/dmd2/samples/d");
        version (Windows) {} else
        {
            copyDirVersioned(cloneDir~"/tools/man", releaseDir~"/dmd2/man");
            // copy man pages from linux build
            copyDir(origDir~"/docs/man", releaseDir~"/dmd2/man");
        }
        makeDir(releaseDir~"/dmd2/html/d/zlib");
        copyFile(cloneDir~"/phobos/etc/c/zlib/ChangeLog", releaseDir~"/dmd2/html/d/zlib/ChangeLog");
        copyFile(cloneDir~"/phobos/etc/c/zlib/README",    releaseDir~"/dmd2/html/d/zlib/README");
        copyFile(cloneDir~"/phobos/etc/c/zlib/zlib.3",    releaseDir~"/dmd2/html/d/zlib/zlib.3");
    }

    // Copy lib
    version(OSX)
    {
        if(do32Bit && do64Bit)
            copyFile(cloneDir~"/phobos/generated/"~osDirName~"/release/libphobos2.a", releaseLib32Dir~"/libphobos2.a");
        else if(do32Bit)
            copyFile(cloneDir~"/phobos/generated/"~osDirName~"/release/32/libphobos2.a", releaseLib32Dir~"/libphobos2_32.a");
        else if(do64Bit)
            copyFile(cloneDir~"/phobos/generated/"~osDirName~"/release/64/libphobos2.a", releaseLib32Dir~"/libphobos2_64.a");
    }
    else version (Windows)
    {
        if(do32Bit)
        {
            copyFile(cloneDir~"/phobos/phobos.lib", osDir~"/lib/phobos.lib");
            copyDir(cloneDir~"/druntime/lib/win32/", osDir~"/lib/", file => file.endsWith(".lib"));
        }
        if(do64Bit)
        {
            copyFile(cloneDir~"/phobos/phobos64.lib", osDir~"/lib64/phobos64.lib");
            copyFile(cloneDir~"/phobos/phobos32mscoff.lib", osDir~"/lib32mscoff/phobos32mscoff.lib");
        }
    }
    else
    {
        import std.range : chain;

        if(do32Bit)
        {
            copyFile(cloneDir~"/phobos/generated/"~osDirName~"/release/32/"~libPhobos32~lib, releaseLib32Dir~"/"~libPhobos32~lib);
            // libphobos2.so.0.68.0, libphobos2.so.0.68, libphobos2.so
            copyDir(cloneDir~"/phobos/generated/"~osDirName~"/release/32/", releaseLib32Dir~"/",
                    file => file.startsWith(chain(libPhobos32, dll)));
        }
        if(do64Bit)
        {
            copyFile(cloneDir~"/phobos/generated/"~osDirName~"/release/64/"~libPhobos64~lib, releaseLib64Dir~"/"~libPhobos64~lib);
            // libphobos2.so.0.68.0, libphobos2.so.0.68, libphobos2.so
            copyDir(cloneDir~"/phobos/generated/"~osDirName~"/release/64/", releaseLib64Dir~"/",
                    file => file.startsWith(chain(libPhobos64, dll)));
        }
    }

    // Copy bin32
    version(OSX) {} else // OSX doesn't include 32-bit tools
    {
        if(do32Bit)
        {
            copyFile(cloneDir~"/dmd/generated/"~osDirName~"/release/32/dmd"~exe, releaseBin32Dir~"/dmd"~exe);
            copyDir(cloneDir~"/tools/generated/"~osDirName~"/32", releaseBin32Dir, file => !file.endsWith(obj));
            copyFile(cloneDir~"/dub/bin/dub32"~exe, releaseBin32Dir~"/dub"~exe);
            if (codesign)
                signBinaries(releaseBin32Dir);
        }
    }

    // Copy bin64
    if(do64Bit)
    {
        copyFile(cloneDir~"/dmd/generated/"~osDirName~"/release/64/dmd"~exe, releaseBin64Dir~"/dmd"~exe);
        version(Windows)
        {
            // patch sc.ini to point to optlink.exe in bin folder
            auto sc_ini = cast(string)std.file.read(cloneDir~"/dmd/ini/windows/bin/sc.ini");
            sc_ini = sc_ini.replace(`%@P%\optlink.exe`, `%@P%\..\bin\optlink.exe`);
            std.file.write(releaseBin64Dir~"/sc.ini", sc_ini);
        }
        else // Win doesn't include 64-bit tools
        {
            copyDir(cloneDir~"/tools/generated/"~osDirName~"/64", releaseBin64Dir, file => !file.endsWith(obj));
        }
        copyFile(cloneDir~"/dub/bin/dub64"~exe, releaseBin64Dir~"/dub"~exe);
        if (codesign)
            signBinaries(releaseBin64Dir);
    }
}

void createZip(string branch)
{
    auto archiveName = baseName(releaseDir)~".zip";
    archiveZip(releaseDir~"/dmd2", archiveName);
}

void signBinaries(string folder)
{
    version (Windows)
    {
        auto script = origDir~"/codesign/sign.ps1";
        auto cert = origDir~"/codesign/win.pfx";
        auto pass = origDir~"/codesign/win.pass";
        auto fingerprint = origDir~"/codesign/win.fingerprint";
        auto cmd = "PowerShell.exe -ExecutionPolicy Bypass -File " ~ quote(script) ~ " " ~ quote(cert) ~ " " ~ quote(fingerprint) ~ " " ~ quote(pass) ~ " ";
        foreach (DirEntry de; dirEntries(folder, SpanMode.breadth))
        {
            if (de.name.extension != exe)
                continue;
            info("Signing "~de.name);
            run(cmd ~ quote(de.name));
        }
    }
}

// Utils -----------------------

void trace(string msg)
{
    writeln(msg);
}

void info(string msg)
{
    writeln(msg);
}

void fatal(string msg)
{
    stderr.writeln("create_dmd_release: Error: "~msg);
}

/// Cleanup a path for display to the user:
/// - Strip current directory prefix, if applicable. (ie, The current directory
///   from the user's perspective, not this program's internal current directory.)
/// - On windows: Convert slashes to backslash.
string displayPath(string path)
{
    version(Windows)
        path = path.replace("/", "\\");

    return chompPrefix(path, origDir ~ dirSeparator);
}

string quote(string str)
{
    version(Windows)
        return `"`~str~`"`;
    else
        return `'`~str~`'`;
}

string releaseBitSuffix(bool has32, bool has64)
{
    if(do32Bit && !do64Bit)
        return releaseBitSuffix32;

    if(do64Bit && !do32Bit)
        return releaseBitSuffix64;

    return "";
}

// Filesystem Utils -----------------------

/// Removes a file if it exists, otherwise do nothing
void removeFile(string path)
{
    if(exists(path))
        std.file.remove(path);
}

void removeFiles(string path, string pattern, SpanMode mode,
    bool delegate(string) filter)
{
    removeFiles(path, pattern, mode, true, filter);
}

void removeFiles(string path, string pattern, SpanMode mode,
    bool followSymlink = true, bool delegate(string) filter = null)
{
    if(mode == SpanMode.breadth)
        throw new Exception("removeFiles can only take SpanMode of 'depth' or 'shallow'");

    auto displaySuffix = mode==SpanMode.shallow? "" : "/*";
    trace("Deleting '"~pattern~"' from '"~displayPath(path~displaySuffix)~"'");

    // Needed to generate 'relativePath' correctly.
    path = path.replace("\\", "/");
    if(!path.endsWith("/", "\\"))
        path ~= "/";

    foreach(DirEntry entry; dirEntries(path[0..$-1], pattern, mode, false))
    {
        if(entry.isFile)
        {
            auto relativePath = entry.replace("\\", "/").chompPrefix(path);

            if(!filter || filter(relativePath))
            {
                trace("    " ~ displayPath(relativePath));
                entry.remove();
            }
            else if(filter)
                trace("    Skipping: " ~ displayPath(relativePath));
        }
    }
}

/// Remove entire directory tree. If it doesn't exist, do nothing.
void removeDir(string path)
{
    if(exists(path))
    {
        trace("Removing dir: "~displayPath(path));

        void removeDirFailed()
        {
            fail(
                "Failed to remove directory: "~displayPath(path)~"\n"~
                "    A process may still holding an open handle within the directory.\n"~
                "    Either delete the directory manually or try again later."
            );
        }

        try
        {
            version(Windows)
                run("rmdir /S /Q "~quote(path));
            else
                run("rm -rf "~quote(path));
        }
        catch(Exception e)
            removeDirFailed();

        if(exists(path))
            removeDirFailed();
    }
}

/// Like mkdirRecurse, but no error if directory already exists.
void makeDir(string path)
{
    if(!exists(path))
    {
        trace("Creating dir: "~displayPath(path));
        mkdirRecurse(path);
    }
}

void changeDir(string path)
{
    trace("Entering dir: "~displayPath(path));

    try
        chdir(path);
    catch(FileException e)
        fail(e.msg);
}

/// Copy file attributes from src file to dest file
/// Does nothing on non-Posix
void copyAttributes(string src, string dest)
{
    // Only needed on Posix
    version(Posix)
    {
        auto attr = cast(mode_t)getAttributes(src);
        auto result = chmod(dest.toStringz(), attr);
        if(result != 0)
            fail("Unable to set attributes on: " ~ dest);
    }
}

/// Recursively copy the contents of a directory, excluding anything
/// untracked or ignored by git.
void copyDirVersioned(string src, string dest, bool delegate(string) filter = null)
{
    auto versionedFiles = gitVersionedFiles(src);
    copyFiles(versionedFiles, src, dest, filter);
}

/// Recursively copy contents of 'src' directory into 'dest' directory.
/// Directory 'dest' will be created if it doesn't exist.
/// Takes optional delegate to filter out any files to not copy.
void copyDir(string src, string dest, bool delegate(string) filter = null)
{
    trace("Copying from '"~displayPath(src)~"' to '"~displayPath(dest)~"'");

    // Needed to generate 'relativePath' correctly.
    src = src.replace("\\", "/");
    if(!src.endsWith("/", "\\"))
        src ~= "/";

    makeDir(dest);
    foreach(DirEntry entry; dirEntries(src[0..$-1], SpanMode.breadth, false))
    {
        auto relativePath = entry.name.replace("\\", "/").chompPrefix(src);

        if (relativePath.baseName.startsWith(".") ||
            filter !is null && !filter(relativePath))
        {
            trace("    Skipping: " ~ displayPath(relativePath));
            continue;
        }

        trace("    " ~ displayPath(relativePath));

        auto destPath = buildPath(dest, relativePath);
        auto srcPath  = buildPath(src,  relativePath);

        version(Posix)
        {
            if(entry.isSymlink)
            {
                run("cp -P "~srcPath~" "~destPath);
                continue;
            }
        }

        if(entry.isDir)
            makeDir(destPath);
        else
        {
            makeDir(dirName(destPath));
            copy(srcPath, destPath);
            copyAttributes(srcPath, destPath);
        }
    }
}

// External Tools -----------------------

/// Like system(), but throws useful Fail message upon failure.
void run(string cmd)
{
    trace("Running: "~cmd);

    stdout.flush();
    stderr.flush();

    auto pid = spawnShell(cmd);
    if(wait(pid) != 0)
        fail("Command failed (ran from dir '"~displayPath(getcwd())~"'): "~cmd);
}

/// Like run(), but captures the standard output and returns it.
string runCapture(string cmd)
{
    trace("Running: "~cmd);

    stdout.flush();
    stderr.flush();

    auto result = executeShell(cmd);
    if(result.status != 0)
        fail("Command failed (ran from dir '"~displayPath(getcwd())~"'): "~cmd);

    return result.output;
}

string[] gitVersionedFiles(string path)
{
    auto saveDir = getcwd();
    scope(exit) changeDir(saveDir);
    changeDir(path);

    Appender!(string[]) versionedFiles;
    // At some point in the spring of 2020, git commands started working as issued from the repository root, not from the cwd.
    // The reason is still a mistery, it has not been reproduced locally. "ls-tree" can be made to work instead of "ls-files".
    // auto gitOutput = runCapture("git ls-files").strip();
    auto toplevel = runCapture("git rev-parse --show-toplevel").strip;
    trace("toplevel = "~toplevel);
    trace("getcwd = "~getcwd;
    auto prefix = toplevel[getcwd.length + 1 .. $];
    trace("prefix = "~prefix);
    auto gitOutput = runCapture("git ls-tree -r HEAD:"~prefix~" --name-only --full-tree").strip();
    // ^^^^
    foreach(filename; gitOutput.splitter("\n"))
        versionedFiles.put(filename);

    return versionedFiles.data;
}
