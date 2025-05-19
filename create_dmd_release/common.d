import std.file, std.path, std.stdio;

//------------------------------------------------------------------------------
// File/Folder tools

///
enum allProjects = ["dmd", "phobos", "tools", "dlang.org", "installer"];

/// Copy files, creating destination directories as needed
void copyFiles(string[] files, string srcDir, string dstDir, bool delegate(string) filter = null)
{
    writefln("Copying the following files from '%s' to '%s':", srcDir, dstDir);
    writefln("%(\t%s\n%)", files);
    foreach(file; files)
    {
        if (filter && !filter(file)) continue;

        auto srcPath  = buildPath(srcDir, file);
        auto dstPath = buildPath(dstDir, file);

        mkdirRecurse(dirName(dstPath));

        copy(srcPath, dstPath);
        setAttributes(dstPath, getAttributes(srcPath));
    }
}

void copyFile(string src, string dst, bool verbose = true)
{
    if (verbose)
        writefln("Copying file '%s' to '%s'.", src, dst);
    mkdirRecurse(dirName(dst));
    copy(src, dst);
    setAttributes(dst, getAttributes(src));
}

void copyFileIfExists(string src, string dst)
{
    if(exists(src))
        copyFile(src, dst);
}

void copyDirectory(string src, string dst, bool verbose = true)
{
    if (verbose)
        writefln("Copying directory '%s' to '%s'.", src, dst);
    dst = buildPath(dst, baseName(src));
    mkdirRecurse(dst);
    foreach (de; dirEntries(src, SpanMode.shallow))
        if (de.isFile)
            copyFile(de, buildPath(dst, baseName(de)), false);
        else
            copyDirectory(de, dst, false);
}

void rmdirDirectoryNoFail(string dir)
{
    try
    {
        if (dir && dir.exists)
            rmdirRecurse(dir);
    }
    catch(FileException e)
    {
        writeln("\033[031m" ~ e.msg ~ "\033[0m");
    }
}

//------------------------------------------------------------------------------
// tmpfile et. al.

// should be in core.stdc.stdlib
version (Posix) extern(C) char* mkdtemp(char* template_);

string mkdtemp()
{
    version (Posix)
    {
        import core.stdc.string : strlen;
        auto tmp = buildPath(tempDir(), "tmp.XXXXXX\0").dup;
        auto dir = mkdtemp(tmp.ptr);
        return dir[0 .. strlen(dir)].idup;
    }
    else
    {
        import std.format, std.random;
        auto p = buildPath(tempDir(), format("tmp.%06X", uniform(0, 0xFFFFFF)));
        mkdirRecurse(p);
        return p;
    }
}

//------------------------------------------------------------------------------
// Download helpers

// templated so that we don't drag in libcurl unnecessarily
template fetchFile()
{
    void fetchFile(string url, string path, bool verify = false, string sha = null)
    {
        import std.array, std.datetime, std.exception, std.net.curl,
            std.path, std.stdio, std.string;
        import std.process : execute;

        auto client = HTTP(url);
        size_t cnt;
        auto app = appender!(ubyte[])();
        ushort statusCode;
        string etag;
        bool abort;
        client.onReceiveStatusLine = (status)
        {
            statusCode = status.code;
        };
        client.onReceiveHeader = (key, value)
        {
            if (key != "etag") return;

            auto petag = path~".etag";
            if (path.exists && petag.exists && cast(string)std.file.read(petag) == value)
            {
                writefln("Using cached download '%s'.", path);
                abort = true;
                return;
            }
            etag = value.idup;
            writefln("Downloading file '%s' to '%s'.", url, path);
        };
        client.onReceive = (data)
        {
            if (!abort) app.put(data);
            return data.length;
        };
        client.onProgress = (dlt, dln, _, _2)
        {
            if (!abort && dlt && cnt++ % 32 == 0)
                writef("Progress: %.1f%% of %s kB\r", 100.0 * dln / dlt, dlt / 1024);
            return abort ? 1 : 0;
        };
        try
            client.perform();
        catch (CurlException ce)
        {
            // stupid std.net.curl throws an exception when aborting, ignore it
            if (!abort) throw ce;
        }

        if (!abort)
        {
            enforce(statusCode / 100 == 2,
                    format("Download of '%s' failed with HTTP status code '%s'.",
                           url, statusCode));
            mkdirRecurse(path.dirName);
            std.file.write(path, app.data);
            app.clear();
            if (etag.length)
                std.file.write(path~".etag", etag);
            writeln(); // CR
            stdout.flush();
        }

        if (verify)
        {
            if (sha)
            {
                import std.digest.sha, std.conv;

                auto data = cast(ubyte[])std.file.read(path);
                SHA256 sha256;
                sha256.start();
                sha256.put(data);
                enforce(sha256.finish() == cast(ubyte[])sha);
            }
            else
            {
                path ~= ".sig";
                if (!path.exists)
                    download(url~".sig", path);
                auto gpg = execute(["gpg", "--verify", path]);
                enforce(!gpg.status, gpg.output);
            }
        }
    }
}

//------------------------------------------------------------------------------
// Zip tools
import std.zip;

void extractZip(string archive, string outputDir)
{
    import std.array : replace;

    scope zip = new ZipArchive(std.file.read(archive));

    string outPath(string name)
    {
        string path = buildPath(outputDir, name.replace("\\", "/"));
        auto dir = dirName(path);
        if (dir != "" && !dir.exists)
            mkdirRecurse(dir);
        return path;
    }

    void setTimeAttrs(string path, ArchiveMember am)
    {
        import std.datetime : DosFileTimeToSysTime;
        auto mtime = DosFileTimeToSysTime(am.time);
        setTimes(path, mtime, mtime);
        if (auto attrs = am.fileAttributes)
            std.file.setAttributes(path, attrs);
    }

    foreach(name, am; zip.directory)
    {
        if(!am.expandedSize)
            continue;
        if (attrIsSymlink(am.fileAttributes))
            continue; // symlinks need to be created after targets
        zip.expand(am);

        auto path = outPath(name);
        std.file.write(path, am.expandedData);
        setTimeAttrs(path, am);
    }

    // create symlinks
    foreach(name, am; zip.directory)
    {
        if (!attrIsSymlink(am.fileAttributes))
            continue;
        zip.expand(am);

        auto path = outPath(name);
        version (Posix) symlink(cast(char[])am.expandedData, path);
        else assert(0);
        setTimeAttrs(path, am);
    }
}

void archiveZip(string inputDir, string archive)
{
    import std.algorithm : startsWith;
    import std.string : chomp, chompPrefix;

    archive = absolutePath(archive);

    scope zip = new ZipArchive();
    auto parentDir = chomp(inputDir, baseName(inputDir));
    foreach (de; dirEntries(inputDir, SpanMode.depth))
    {
        if(!de.isFile || de.baseName.startsWith(".git", ".DS_Store")) continue;
        auto path = chompPrefix(de.name, parentDir);
        zip.addMember(toArchiveMember(de, path));
    }
    if(exists(archive))
        remove(archive);
    std.file.write(archive, zip.build());
}

private ArchiveMember toArchiveMember(ref DirEntry de, string path)
{
    auto am = new ArchiveMember();
    am.compressionMethod = CompressionMethod.deflate;
    am.time = de.timeLastModified;
    am.name = path;
    am.fileAttributes = de.linkAttributes;
    version (Posix) if (de.isSymlink)
    {
        am.expandedData = cast(ubyte[])readLink(de.name);
        return am;
    }
    am.expandedData = cast(ubyte[])std.file.read(de.name);
    return am;
}

void archiveLZMA(string inputDir, string archive)
{
    import std.exception : enforce;
    import std.algorithm.searching : endsWith;
    import std.process : execute;
    archive = absolutePath(archive);

    auto saveDir = getcwd();
    scope(exit) chdir(saveDir);
    chdir(dirName(inputDir));

    auto cmd = archive.endsWith(".7z") ? ["7z", "a", archive, baseName(inputDir)] :
            ["tar", "-Jcf", archive, baseName(inputDir)];
    auto rc = execute(cmd);
    enforce(!rc.status, rc.output);
}

// generic extract, might require tar, xz, 7z depending on archive format
void extract(string archive, string outputDir)
{
    import std.exception : enforce;
    import std.algorithm.searching : endsWith;
    import std.process : execute;

    string[] cmd;
    if (archive.endsWith(".zip"))
        return extractZip(archive, outputDir);
    else if (archive.endsWith(".tar.xz"))
        cmd = ["tar", "-C", outputDir, "-Jxf", archive];
    else if (archive.endsWith(".7z"))
        cmd = ["7z", "x", "-o"~outputDir, archive];
    else
        assert(0, "Unsupported archive format "~archive~".");

    if (!outputDir.exists)
        mkdirRecurse(outputDir);
    auto rc = execute(cmd);
    enforce(!rc.status, rc.output);
}
