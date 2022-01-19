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

module moss.container.mounts;

/**
 * Helps us to define some basic mount options
 */
public enum MountOptions
{
    Bind = 1 << 0,
    ReadOnly = 1 << 1,
}

/**
 * Defines a mountpoint on the system with source and target
 */
public struct Mount
{
    /**
     * Source for this mount point
     */
    string source;

    /**
     * Target for this mountpoint
     */
    string target;

    /**
     * Any additional mount options
     */
    MountOptions options;
}
