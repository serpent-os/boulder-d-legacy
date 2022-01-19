/*
 * This file is part of moss-cintainer.
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

module main;

import moss.container;
import core.sys.posix.unistd;
import core.stdc.stdio;

/**
 * Main entry point into the moss-container binary
 */
extern (C) int main(const char*[] argv)
{
    auto euid = geteuid();
    if (euid != 0)
    {
        fprintf(stderr, "%s must be run as root, aborting\n", argv[0]);
        return 1;
    }
    Container c = Container("/home/ikey/serpent/moss/destdir");
    return c.run();
}
