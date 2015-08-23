import std.file, std.path, std.stdio;

//------------------------------------------------------------------------------
// File/Folder tools

///
enum allProjects = ["dmd", "druntime", "phobos", "tools", "dlang.org", "installer"];

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

void copyFile(string src, string dst)
{
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
        return buildPath(tempDir(), format("tmp.%06X\0", uniform(0, 0xFFFFFF)));
    }
}

//------------------------------------------------------------------------------
// Download helpers

// templated so that we don't drag in libcurl unnecessarily
template fetchFile()
{
    pragma(lib, "curl");

    void fetchFile(string url, string path)
    {
        import std.array, std.datetime, std.exception, std.net.curl,
            std.path, std.stdio, std.string;
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
            if (abort) return;
            throw ce;
        }
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
}

//------------------------------------------------------------------------------
// Zip tools
import std.zip;

void extractZip(string archive, string outputDir)
{
    import std.array : replace;

    scope zip = new ZipArchive(std.file.read(archive));
    foreach(name, am; zip.directory)
    {
        if(!am.expandedSize) continue;

        string path = buildPath(outputDir, name.replace("\\", "/"));
        auto dir = dirName(path);
        if (dir != "" && !dir.exists)
            mkdirRecurse(dir);
        zip.expand(am);
        std.file.write(path, am.expandedData);
        import std.datetime : DosFileTimeToSysTime;
        auto mtime = DosFileTimeToSysTime(am.time);
        setTimes(path, mtime, mtime);
        if (auto attrs = am.fileAttributes)
            std.file.setAttributes(path, attrs);
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
