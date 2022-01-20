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

/**
 * Disclaimer: We fully intend to replace fakeroot with something more efficient
 * in future but for now let's just manage that stuff here.
 */

module moss.container.fakeroot;

import moss.container.context;
import std.file : exists;
import std.path : buildPath;

/**
 * Known locations for the fakeroot executable.
 * Special care is taken to avoid `fakeroot-tcp`
 * as it is unacceptably slow on Linux
 */
public enum FakerootBinary : string
{
    None = null,
    Sysv = "/usr/bin/fakeroot-sysv",
    Default = "/usr/bin/fakeroot"
}

/**
 * Determine the availability of fakeroot
 */
package FakerootBinary discoverFakeroot()
{
    auto locations = [FakerootBinary.Sysv, FakerootBinary.Default,];

    /* Iterate sane locations of fakeroot */
    foreach (searchLocation; locations)
    {
        auto fullPath = context.rootfs.buildPath((cast(string) searchLocation)[1 .. $]);
        if (fullPath.exists)
        {
            return searchLocation;
        }
    }

    return FakerootBinary.None;
}
