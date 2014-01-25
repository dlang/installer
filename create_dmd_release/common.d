// Zip tools
import std.file, std.path, std.zip;

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
