/+++
Prerequisites to Compile:
-------------------------
- Working D compiler

Prerequisites to Run:
---------------------
- Git
- Posix: Working gcc toolchain, including GNU make which is not installed on
  FreeBSD by default. On OSX, you can install the gcc toolchain through Xcode.
- Windows: Working DMC (incl. sppn.exe and implib.exe) and 32/64-bit MSVC
  toolchains. dmc.exe, DM lib.exe, sppn.exe and implib.exe must be found in PATH,
  so it's recommended to set the DMC bin dir as *first* dir in PATH.
  Also, this environment variable must be set:
    LDC_VSDIR: Visual Studio directory containing the MSVC toolchains
  Examples:
    set LDC_VSDIR="C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\"
- Windows: A GNU make, found in PATH as mingw32-make (to avoid DM make.exe bundled with DMC).
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

    immutable exe           = ".exe";
    immutable lib           = ".lib";
    immutable obj           = ".obj";
    immutable dll           = ".dll";
    immutable libPhobos32   = "phobos";
    immutable libPhobos64   = "phobos64";
    immutable build64BitTools = false;

    immutable osDirName     = "windows";
    immutable make          = "mingw32-make";
    immutable suffix32      = "";   // bin/lib  TODO: adapt scripts to use 32
    immutable suffix64      = "64"; // bin64/lib64
}
else version(Posix)
{
    immutable defaultWorkDirName = ".create_dmd_release";
    immutable exe           = "";
    immutable lib           = ".a";
    immutable obj           = ".o";
    immutable libPhobos32   = "libphobos2";
    immutable libPhobos64   = "libphobos2";
    immutable build64BitTools    = true;

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
        if(do32Bit)
        {
            fatal("32-bit builds no longer supported on OSX.");
            return 1;
        }
    }

    if(!do32Bit && !do64Bit)
        do32Bit = do64Bit = true;

    if(customExtrasDir != "")
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
    auto saveDir = getcwd();
    scope(exit) changeDir(saveDir);

    info("Cleaning DMD");
    changeDir(cloneDir~"/dmd");
    run("git clean -f -x -d"); // remove all untracked/ignored files
    run("git checkout ."); // undo local changes, e.g. VERSION

    info("Cleaning Phobos");
    changeDir(cloneDir~"/phobos");
    run("git clean -f -x -d");

    info("Cleaning Tools");
    changeDir(cloneDir~"/tools");
    run("git clean -f -x -d");
}

void buildAll(string branch)
{
    if(do32Bit)
        buildAll(Bits.bits32, branch);

    if(do64Bit)
        buildAll(Bits.bits64, branch);
}

void buildAll(Bits bits, string branch)
{
    auto saveDir = getcwd();
    scope(exit) changeDir(saveDir);

    const is32 = bits == Bits.bits32;

    version (Windows)
    {
        // Setup MSVC environment for x64/x86 native builds
        const vcVars = quote(buildPath(environment["LDC_VSDIR"], `VC\Auxiliary\Build\vcvarsall.bat`));
        version (Win64)
            enum arch32 = "amd64_x86";
        else
            enum arch32 = "x86";

        const msvcVars = vcVars~" "~(is32 ? arch32 : "x64")~" && ";
    }
    else
        enum msvcVars = "";

    const bitsStr = is32 ? "32" : "64";
    const bitsDisplay = toString(bits);
    const makeModel = " MODEL="~bitsStr;
    const jobs = " -j4";
    const dmdEnv = ` "DMD=`~cloneDir~`/dmd/generated/`~osDirName~`/release/`~bitsStr~`/dmd`~exe~`"`;
    const isRelease = " ENABLE_RELEASE=1";
    //Enable lto for everything except FreeBSD - the generated dmd segfaults immediatly.
    version (FreeBSD)
        const ltoOption = " ENABLE_LTO=0";
    else version (linux)
        const ltoOption = " ENABLE_LTO=" ~ (is32 ? "0" : "1");
    else
        const ltoOption = " ENABLE_LTO=1";
    const latest = " LATEST="~branch;
    // PIC libraries on amd64 for PIE-by-default distributions, see Bugzilla 16794
    version (linux)
        const pic = is32 ? "" : " PIC=1";
    else
        const pic = "";

    // common make arguments
    const makecmd = make~jobs~makeModel~dmdEnv~isRelease~latest;

    info("Building DMD "~bitsDisplay);
    changeDir(cloneDir~"/dmd");
    run(msvcVars~makecmd~ltoOption~" HOST_DMD="~hostDMD~" dmd");

    info("Building Druntime "~bitsDisplay);
    changeDir(cloneDir~"/dmd/druntime");
    run(msvcVars~makecmd~pic);

    info("Building Phobos "~bitsDisplay);
    changeDir(cloneDir~"/phobos");
    run(msvcVars~makecmd~pic);

    version(Windows) if (is32)
    {
        const makecmd_omf = makecmd.replace(makeModel, " MODEL=32omf");

        info("Building Druntime 32omf");
        changeDir(cloneDir~"/dmd/druntime");
        run(makecmd_omf);

        info("Building OMF import libraries");
        changeDir(cloneDir~"/dmd/druntime/def");
        run(make~jobs);

        info("Building Phobos 32omf");
        changeDir(cloneDir~"/phobos");
        run(makecmd_omf);
    }

    // Build docs
    if(!skipDocs)
    {
        version (linux)
        {
            if (!is32)
            {
                changeDir(cloneDir~"/dlang.org");
                run(makecmd~" DOC_OUTPUT_DIR="~origDir~"/docs -f posix.mak release");
                // copy generated man pages to docs/man which gets copied to all other platforms
                copyDir(cloneDir~"/dmd/generated/docs/man", origDir~"/docs/man");
            }
        }
    }

    if(build64BitTools || is32)
    {
        // Build the tools using the host compiler
        auto tools_makecmd = makecmd.replace(dmdEnv, " DMD=" ~ hostDMD);

        // Override DFLAGS for a release build defaulting to DMD.
        tools_makecmd ~= ` DFLAGS="-O -release -m` ~ bitsStr ~ ` -version=DefaultCompiler_DMD"`;

        info("Building Tools "~bitsDisplay);
        changeDir(cloneDir~"/tools");
        run(tools_makecmd~" rdmd ddemangle dustmite");
    }

    bool buildDub = true; // build64BitTools || is32;
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

    static void ensureIsClean(string repoDir)
    {
        const output = runCapture("cd "~quote(repoDir)~" && git status --porcelain");
        if (output.length)
            fail("Repo '"~repoDir~"' is dirty:\n" ~ output);
    }

    // Copy sources
    ensureIsClean(cloneDir~"/dmd");
    ensureIsClean(cloneDir~"/phobos");
    copyDirVersioned(cloneDir~"/dmd/compiler", "src", releaseDir~"/dmd2/src/dmd");
    copyDirVersioned(cloneDir~"/dmd/druntime", null, releaseDir~"/dmd2/src/druntime");
    copyDirVersioned(cloneDir~"/phobos", null, releaseDir~"/dmd2/src/phobos");
    copyDirVersioned(cloneDir~"/dmd/compiler", "ini/" ~ osDirName, releaseDir~"/dmd2/" ~ osDirName);

    // druntime/doc doesn't get generated on Windows with --only-64, I don't know why.
    if(exists(cloneDir~"/dmd/druntime/doc"))
        copyDir(cloneDir~"/dmd/druntime/doc", releaseDir~"/dmd2/src/druntime/doc");
    copyDir(cloneDir~"/dmd/druntime/import", releaseDir~"/dmd2/src/druntime/import");
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
        copyDirVersioned(cloneDir~"/dmd/compiler", "samples", releaseDir~"/dmd2/samples/d");
        version (Windows) {} else
        {
            copyDirVersioned(cloneDir~"/tools", "man", releaseDir~"/dmd2/man");
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
        copyFile(cloneDir~"/phobos/generated/"~osDirName~"/release/64/libphobos2.a", releaseLib32Dir~"/libphobos2.a");
    else version (Windows)
    {
        if(do32Bit)
        {
            copyFile(cloneDir~"/phobos/phobos32mscoff.lib", osDir~"/lib32mscoff/phobos32mscoff.lib");
            // OMF:
            copyFile(cloneDir~"/phobos/phobos.lib", osDir~"/lib/phobos.lib");
            copyDir(cloneDir~"/dmd/druntime/def/", osDir~"/lib/", file => file.endsWith(".lib"));
        }
        if(do64Bit)
        {
            copyFile(cloneDir~"/phobos/phobos64.lib", osDir~"/lib64/phobos64.lib");
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
                    file => file.startsWith(chain(libPhobos32, dll)) && !file.endsWith(obj));
        }
        if(do64Bit)
        {
            copyFile(cloneDir~"/phobos/generated/"~osDirName~"/release/64/"~libPhobos64~lib, releaseLib64Dir~"/"~libPhobos64~lib);
            // libphobos2.so.0.68.0, libphobos2.so.0.68, libphobos2.so
            copyDir(cloneDir~"/phobos/generated/"~osDirName~"/release/64/", releaseLib64Dir~"/",
                    file => file.startsWith(chain(libPhobos64, dll)) && !file.endsWith(obj));
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
            auto sc_ini = cast(string)std.file.read(cloneDir~"/dmd/compiler/ini/windows/bin/sc.ini");
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
    version (OSX)
    {
        assert(!do32Bit && do64Bit);
        return "";
    }
    else
    {
        if(do32Bit && !do64Bit)
            return releaseBitSuffix32;

        if(do64Bit && !do32Bit)
            return releaseBitSuffix64;

        return "";
    }
}

// Filesystem Utils -----------------------

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
void copyDirVersioned(string repo, string path, string dest, bool delegate(string) filter = null)
{
    auto versionedFiles = gitVersionedFiles(repo, path);
    copyFiles(versionedFiles, buildPath(repo, path), dest, filter);
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

string[] gitVersionedFiles(string repo, string path)
{
    auto saveDir = getcwd();
    scope(exit) changeDir(saveDir);
    changeDir(repo);

    path = path.replace("\\", "/");
    if(!path.empty && !path.endsWith("/"))
        path ~= "/";

    Appender!(string[]) versionedFiles;
    auto gitOutput = runCapture("git ls-files -- "~path).strip();
    foreach(filename; gitOutput.splitter("\n"))
    {
        assert(filename.startsWith(path));
        versionedFiles.put(filename[path.length .. $]);
    }

    return versionedFiles.data;
}
