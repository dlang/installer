import std.file, std.path;

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
        import std.net.curl, std.path, std.stdio;
        if (path.exists) return;
        auto client = HTTP(url);
        size_t cnt;
        client.onProgress = (dlt, dln, _, _2)
        {
            if (dlt && cnt++ % 32 == 0)
                writef("Progress: %.1f%% of %s kB\r", 100.0 * dln / dlt, dlt / 1024);
            return 0;
        };
        writefln("Downloading file '%s' to '%s'.", url, path);
        mkdirRecurse(path.dirName);
        std.file.write(path, get!(HTTP, ubyte)(url, client));
        writeln(); // CR
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

        const os = am.madeVersion & 0xFF00;
        const fromWindows = os == 0x0000 || os == 0x0b00;

        string path = buildPath(outputDir, fromWindows ? replace(name, "\\", "/") : name);
        auto dir = dirName(path);
        if (dir != "" && !dir.exists)
            mkdirRecurse(dir);
        zip.expand(am);
        std.file.write(path, am.expandedData);
        import std.datetime : DosFileTimeToSysTime;
        auto mtime = DosFileTimeToSysTime(am.time);
        setTimes(path, mtime, mtime);
        version (Posix) if (fromWindows) continue;
        std.file.setAttributes(path, am.fileAttributes);
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
    am.expandedData = cast(ubyte[])std.file.read(de.name);
    am.fileAttributes = de.attributes;
    return am;
}
