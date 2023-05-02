module moss.container.mapping;

import core.stdc.stdio : FILE;
import core.stdc.stdlib;
import core.sys.posix.fcntl;
import core.sys.posix.unistd : close, getegid, geteuid, write;
import std.conv : to;
import std.format : format;
import std.process : environment, spawnProcess, wait;
import std.string : toStringz;
import std.typecons : Tuple, tuple;

package:

static immutable auto rootUGID = 0;
static immutable auto unprivilegedUGID = 1;

void mapRootUser(int pid)
{

    auto uids = [IDMap(rootUGID, geteuid(), 1)];
    auto gids = [IDMap(rootUGID, getegid(), 1)];

    auto sub = subID();
    sub[0].inner = unprivilegedUGID;
    uids ~= sub[0];
    sub[1].inner = unprivilegedUGID;
    gids ~= sub[1];

    mapWithoutCapability(pid, uids, gids);
}

void mapHostID(int pid, int hostUID, int hostGID)
{
    auto uids = [IDMap(rootUGID, unprivilegedUGID, hostUID), IDMap(hostUID, rootUGID, 1)];
    auto gids = [IDMap(rootUGID, unprivilegedUGID, hostGID), IDMap(hostGID, rootUGID, 1)];

    mapWithCapability(pid, uids, gids);
}

private:

struct IDMap
{
    int inner;
    int outer;
    int length;

    string toString() const pure @safe
    {
        return format!"%s %s %s"(this.inner, this.outer, this.length);
    }
}

int mapWithoutCapability(int pid, IDMap[] uids, IDMap[] gids)
{
    /* We could write the uid_map and gid_map files ourselves
     * if we wanted to run containerized processes only as root.
     * But since we want to be able to drop privileges by setting
     * a different UID and GID, we require *two* associations.
     * This is impossible without CAP_SETUID capability. `newuidmap`
     * has it, so we'll use it.
     * See https://man7.org/linux/man-pages/man7/user_namespaces.7.html
     * at chapter "Defining user and group ID mappings: writing to uid_map and gid_map".
     */

    const auto pidString = to!string(pid);
    string[] mapsToArgs(IDMap[] maps)
    {
        string[] args;
        foreach (ref map; maps)
        {
            args ~= [
                to!string(map.inner), to!string(map.outer),
                to!string(map.length)
            ];
        }
        return args;
    }

    int status;
    status = spawnProcess("newuidmap" ~ (pidString ~ mapsToArgs(uids))).wait();
    if (status < 0)
    {
        return status;
    }
    status = spawnProcess("newgidmap" ~ (pidString ~ mapsToArgs(gids))).wait();

    return status;
}

extern (C)
{
    bool subid_init(const char* progname, FILE* logfd);
    struct subid_range
    {
        ulong start;
        ulong count;
    }
    int subid_get_uid_ranges(const char* owner, subid_range** ranges);
    int subid_get_gid_ranges(const char* owner, subid_range** ranges);
}

Tuple!(IDMap, IDMap) subID()
{
    auto user = environment.get("USER");
    assert(user != "", "USER environment variable is not defined");

    /* There may be multiple rages. We just need one, so consider the first. */
    subid_range* uid;
    subid_range* gid;
    int ret;
    subid_init(null, null);
    ret = subid_get_uid_ranges(user.toStringz(), &uid);
    assert(ret > 0, "Failed to get UID range, or no ranges available");
    ret = subid_get_gid_ranges(user.toStringz(), &gid);
    assert(ret > 0, "Failed to get GID range, or no ranges available");

    return tuple(
        IDMap(0, cast(int) uid.start, cast(int) uid.count),
        IDMap(0, cast(int) gid.start, cast(int) gid.count),
    );
}

void mapWithCapability(int pid, IDMap[] uids, IDMap[] gids)
{
    string uidString;
    foreach (uid; uids)
    {
        uidString ~= uid.toString() ~ "\n";
    }
    string gidString;
    foreach (gid; gids)
    {
        gidString ~= gid.toString() ~ "\n";
    }
    Tuple!(string, string)[] mapping = [
        tuple(format!"/proc/%s/gid_map"(pid), uidString),
        tuple(format!"/proc/%s/uid_map"(pid), gidString),
    ];

    foreach (ref entry; mapping)
    {
        auto fd = open(entry[0].toStringz(), O_WRONLY);
        assert(fd > 0, format!"Failed to open %s"(entry[0]));
        scope (exit)
        {
            close(fd);
        }
        const auto ret = write(fd, entry[1].ptr, entry[1].length);
        assert(ret == entry[1].length, format!"Failed to write into %s"(entry[0]));
    }
}
