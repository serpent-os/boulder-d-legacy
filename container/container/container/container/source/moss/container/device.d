/* SPDX-License-Identifier: Zlib */

/**
 * Integration with `dev_t` types
 *
 * Basic manipulation of the `dev_t` POSIX type is supported
 * along with a helper to create device nodes.
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.container.device;

public import core.sys.posix.sys.stat : S_IFCHR;
public import std.conv : octal;
import core.sys.posix.sys.stat;
import moss.container.context;
import std.file : exists, mkdir, symlink;
import std.path : baseName;
import std.stdint : uint32_t;
import std.string : format, toStringz;
import std.array : join;

alias DeviceIdentifer = dev_t;

/**
 * Return a DeviceIdentifier major number
 */
pure DeviceIdentifer major(in DeviceIdentifer dev) @safe @nogc nothrow
{
    return dev >> 8;
}

/**
 * Return a DeviceIdentifier minor number
 */
pure DeviceIdentifer minor(in DeviceIdentifer dev) @safe @nogc nothrow
{
    return dev & 0xff;
}

/**
 * Construct a DeviceIdentifier from the major and minor numbers
 */
pure DeviceIdentifer mkdev(in uint32_t major, in uint32_t minor) @safe @nogc nothrow
{
    return (major << 8) | minor;
}

/**
 * A DeviceNode encapsulates the absolute basics needed to construct
 * our required devices
 */
package struct DeviceNode
{
    /**
     * Where will we create the node?
     */
    string target;

    /**
     * What mode will it have?
     */
    mode_t mode;

    /**
     * Actual device info
     */
    DeviceIdentifer dev = 0;

    /**
     * Create the device node
     */
    bool create()
    {
        auto fullPath = context.joinPath(target);
        if (mknod(fullPath.toStringz, mode, dev) != 0)
        {
            return false;
        }
        auto charPath = context.joinPath("/dev/char");
        if (!charPath.exists)
        {
            charPath.mkdir();
        }
        auto charDevPath = join([
                charPath, format!"%d:%d"(dev.major, dev.minor)
                ], "/");
        auto sourceLink = format!"../%s"(fullPath.baseName);
        symlink(sourceLink, charDevPath);
        return chmod(fullPath.toStringz, mode ^ S_IFCHR) == 0;
    }
}
