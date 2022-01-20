/*
 * This file is part of moss-container.
 *
 * Copyright © 2020-2022 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.container.device;

import core.sys.posix.sys.stat;
import std.stdint : uint32_t;
import moss.container.context;
import std.string : toStringz, format;
import std.file : exists, mkdir, symlink;
import std.path : buildPath, baseName;

public import std.conv : octal;
public import core.sys.posix.sys.stat : S_IFCHR;

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
        if (fullPath.exists)
        {
            return true;
        }
        if (mknod(fullPath.toStringz, mode, dev) != 0)
        {
            return false;
        }
        auto charPath = context.joinPath("/dev/char");
        if (!charPath.exists)
        {
            charPath.mkdir();
        }
        auto charDevPath = charPath.buildPath(format!"%d:%d"(dev.major, dev.minor));
        if (!charDevPath.exists)
        {
            auto sourceLink = format!"../%s"(fullPath.baseName);
            symlink(sourceLink, charDevPath);
        }
        return chmod(fullPath.toStringz, mode ^ S_IFCHR) == 0;
    }
}
