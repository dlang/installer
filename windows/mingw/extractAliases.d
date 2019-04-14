import std.file;
import std.process;
import std.stdio;
import std.string;

string untilFirstSpace(string str)
{
    const spaceIndex = str.indexOf(' ');
    return spaceIndex < 0 ? str : str[0 .. spaceIndex];
}

int main(string[] args)
{
    if (args.length != 2)
    {
        writefln("Usage: %s <path to .lib file>", args[0]);
        return 1;
    }

    const command = `dumpbin /symbols "` ~ args[1] ~ `"`;
    const result = executeShell(command);
    if (result.status)
    {
        writefln("Error: '%s' failed with status %d", command, result.status);
        return 1;
    }

    writeln("; aliases extracted from ", args[1]);

    const lines = splitLines(result.output);
    foreach (i; 1 .. lines.length-1)
    {
        const line = lines[i];
        const previousLine = lines[i-1];
        const nextLine = lines[i+1];

        const weakExternalIndex = line.indexOf(" WeakExternal | ");
        if (weakExternalIndex < 0)
            continue;
        if (nextLine.indexOf(" 2 Alias record") < 0)
            continue;
        const externalIndex = previousLine.indexOf(" External     | ");
        if (externalIndex < 0)
            continue;

        const weakName = untilFirstSpace(line[weakExternalIndex+16 .. $]);
        const realName = untilFirstSpace(previousLine[externalIndex+16 .. $]);

        writeln(weakName, "=", realName);
    }

    return 0;
}
