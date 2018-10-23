//
// Convert MingGW-w64 definition files to COFF import librries
//
// Distributed under the Boost Software License, Version 1.0.
//   (See accompanying file LICENSE_1_0.txt or copy at
//         http://www.boost.org/LICENSE_1_0.txt)
//
// usage: buildsdk [x86|x64] [mingw-w64-folder] [output-folder]
//
// source files extracted from MinGW-w64:
// https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v6.0.0.tar.bz2
//
// assumes VC tools cl, lib and ml installed and found through path
//  and configured to the appropriate architecture
//

import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;

version = verbose;

bool x64;
string[string] weakSymbols; // weak name => real name


void runShell(string cmd)
{
    version (verbose)
        writeln(cmd);
    const rc = executeShell(cmd);
    if (rc.status)
    {
        writeln("'", cmd, "' failed with status ", rc.status);
        writeln(rc.output);
        throw new Exception("'" ~ cmd ~ "' failed");
    }
}

// Preprocesses a 'foo.def.in' file to 'foo.def'.
void generateDef(string inFile, string outFile)
{
    const includeDir = buildPath(dirName(dirName(inFile)), "def-include");
    const archDefine = x64 ? "DEF_X64" : "DEF_I386";
    runShell(`cl /EP /D` ~ archDefine ~ `=1 "/I` ~ includeDir ~ `" "` ~ inFile ~ `" > "` ~ outFile ~ `"`);
}

void sanitizeDef(string defFile)
{
    const lines = std.file.readText(defFile).splitLines;

    bool touched = false;
    const newLines = lines.map!((const string line)
    {
        string l = line;

        if (l == "LIBRARY vcruntime140_app")
            l = `LIBRARY "VCRUNTIME140.dll"`;

        // The MinGW-w64 .def files specify weak external symbols as 'alias == realName'.
        if (l.length > 1 && l[0] != ';')
        {
            const i = l.indexOf(" == ");
            if (i > 0)
            {
                const weakName = l[0 .. i];
                const realName = l[i+4 .. $];
                weakSymbols[weakName] = realName;

                l = ";" ~ l;
            }
        }

        // Don't export function 'atexit'; we have our own in msvc_atexit.c.
        if (l == "atexit" /* msvcr120 */ || l == "atexit DATA" /* < 120 */)
            l = "";

        // Do export function '__chkstk' (ntdll.dll).
        // LLVM emits calls to it to detect stack overflows with '_alloca'.
        if (l == ";__chkstk")
            l = "__chkstk";

        if (l !is line)
            touched = true;

        return l;
    }).array;

    if (touched)
        std.file.write(defFile, newLines.join("\n"));
}

void copyDefs(string inDir, string outDir)
{
    mkdirRecurse(outDir);

    foreach (f; std.file.dirEntries(inDir, SpanMode.shallow))
    {
        const path = f.name;
        const lowerPath = toLower(path);
        string outFile;

        if (lowerPath.endsWith(".def.in"))
        {
            auto base = baseName(path)[0 .. $-7];
            if (base == "vcruntime140_app")
                base = "vcruntime140";

            outFile = buildPath(outDir, base ~ ".def");
            generateDef(path, outFile);
        }
        else if (lowerPath.endsWith(".def"))
        {
            outFile = buildPath(outDir, baseName(path));
            std.file.copy(path, outFile);
        }

        if (outFile !is null)
            sanitizeDef(outFile);
    }
}

void def2implib(string defFile)
{
    const libFile = setExtension(defFile, ".lib");
    const arch = x64 ? "X64" : "X86";
    runShell(`lib /MACHINE:` ~ arch ~ ` "/DEF:` ~ defFile ~ `" "/OUT:` ~ libFile ~ `"`);
    std.file.remove(setExtension(defFile, ".exp"));
}

void defs2implibs(string dir)
{
    foreach (f; std.file.dirEntries(dir, SpanMode.shallow))
    {
        const path = f.name;
        if (toLower(path).endsWith(".def"))
            def2implib(path);
    }
}

void buildMsvcrt(string outDir)
{
    outDir ~= "/";
    const cl = "cl /c /Zl ";
    const lib = "lib /MACHINE:" ~ (x64 ? "X64" : "X86") ~ " ";

    // compile some additional objects to be merged into the msvcr*.lib files
    runShell(cl ~ `"/Fo` ~ outDir ~ `msvcrt_stub0.obj" /D_APPTYPE=0 msvcrt_stub.c`);
    runShell(cl ~ `"/Fo` ~ outDir ~ `msvcrt_stub1.obj" /D_APPTYPE=1 msvcrt_stub.c`);
    runShell(cl ~ `"/Fo` ~ outDir ~ `msvcrt_stub2.obj" /D_APPTYPE=2 msvcrt_stub.c`);
    runShell(cl ~ `"/Fo` ~ outDir ~ `msvcrt_data.obj" msvcrt_data.c`);
    runShell(cl ~ `"/Fo` ~ outDir ~ `msvcrt_atexit.obj" msvcrt_atexit.c`);
    auto objs = [ "msvcrt_stub0.obj", "msvcrt_stub1.obj", "msvcrt_stub2.obj", "msvcrt_data.obj", "msvcrt_atexit.obj" ];
    if (!x64)
    {
        runShell(`ml /c "/Fo` ~ outDir ~ `msvcrt_abs.obj" msvcrt_abs.asm`);
        objs ~= "msvcrt_abs.obj";
    }

    // merge into libs
    const additionalMsvcrtObjs = objs.map!(a => `"` ~ outDir ~ a ~ `"`).join(" ");
    foreach (f; std.file.dirEntries(outDir[0 .. $-1], "*.lib", SpanMode.shallow))
    {
        const lowerBase = toLower(baseName(f.name));
        if (lowerBase.startsWith("msvcr") || lowerBase.startsWith("ucrtbase"))
            runShell(lib ~ `"` ~ f.name ~ `" ` ~ additionalMsvcrtObjs);
    }

    // create empty uuid.lib (expected by dmd, but UUIDs already in druntime)
    std.file.write(outDir ~ "empty.c", "");
    runShell(cl ~ `"/Fo` ~ outDir ~ `uuid.obj" "` ~ outDir ~ `empty.c"`);
    runShell(lib ~ `"/OUT:` ~ outDir ~ `uuid.lib" "` ~ outDir ~ `uuid.obj"`);
    objs ~= "uuid.obj";
    std.file.remove(outDir ~ "empty.c");

    foreach (f; objs)
        std.file.remove(outDir ~ f);
}

void buildOldnames(string outDir)
{
    const cPrefix = x64 ? "" : "_";
    const oldnames_c =
        // access this __ref_oldnames symbol to drag in the generated linker directives (msvcrt_stub.c)
        "int __ref_oldnames;\n" ~
        weakSymbols.byKeyValue.map!(pair =>
            `__pragma(comment(linker, "/alternatename:` ~ cPrefix ~ pair.key ~ `=` ~ cPrefix ~ pair.value ~ `"));`
        ).join("\n");

    version (verbose)
        writeln("\nAuto-generated oldnames.c:\n----------\n", oldnames_c, "\n----------\n");

    const src = buildPath(outDir, "oldnames.c");
    std.file.write(src, oldnames_c);

    const obj = setExtension(src, ".obj");
    runShell(`cl /c /Zl "/Fo` ~ obj ~ `" "` ~ src ~ `"`);

    const lib = setExtension(src, ".lib");
    runShell(`lib /MACHINE:` ~ (x64 ? "X64" : "X86") ~ ` "/OUT:` ~ lib ~ `" "` ~ obj ~ `"`);

    std.file.remove(src);
    std.file.remove(obj);
}

void main(string[] args)
{
    x64 = (args.length > 1 && args[1] == "x64");
    const mingwDir = (args.length > 2 ? args[2] : "mingw-w64");
    string outDir = x64 ? "lib64" : "lib32";
    if (args.length > 3)
        outDir = args[3];

    copyDefs(buildPath(mingwDir, "mingw-w64-crt", "lib-common"), outDir);
    copyDefs(buildPath(mingwDir, "mingw-w64-crt", "lib" ~ (x64 ? "64" : "32")), outDir);

    defs2implibs(outDir);

    buildMsvcrt(outDir);
    buildOldnames(outDir);

    //version (verbose) {} else
        foreach (f; std.file.dirEntries(outDir, "*.def", SpanMode.shallow))
            std.file.remove(f.name);
}
