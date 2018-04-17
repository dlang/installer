import std.net.curl, std.stdio;

int main()
{
    // test a couple of domains for resilience against server, DNS, and network failures
    foreach (dmn; ["dlang.org", "dconf.org", "downloads.dlang.org", "ci.dlang.io"])
    {
        try
        {
            auto res = get(dmn);
            if (res.length)
            {
                writeln("Succeeded to GET ", dmn);
                return 0;
            }
            else
            {
                stderr.writeln("GET ", dmn, " returned an empty result");
                return 1;
            }
        }
        catch (Throwable e)
        {
            stderr.writeln("Failed to GET ", dmn);
            stderr.writeln(e.message);
        }
    }
    return 1;
}
