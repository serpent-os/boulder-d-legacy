/* SPDX-License-Identifier: Zlib */

/**
 * Drafter - License engine
 *
 * Preloading and comparison of licenses
 *
 * Authors: © 2020-2022 Serpent OS Developers
 * License: ZLib
 */

module drafter.license.engine;

import std.exception : enforce;
import std.file : dirEntries, SpanMode, exists, DirEntry;
import std.path : baseName;
import std.algorithm : map, filter, each;
import std.uni : isWhite, toLower;
import std.array : array;
import std.experimental.logger;
import std.parallelism : taskPool;
import drafter.license : License;
import std.mmfile;
import std.container.rbtree;

/**
 * Load SPDX license data from disk
 */
static private License* loadLicense(DirEntry entry)
{
    scope inp = new MmFile(entry.name);
    auto text = cast(string)((cast(ubyte[]) inp[0 .. $]));
    auto filteredText = text.filter!((c) => !c.isWhite)
        .map!((c) => c.toLower);
    auto bn = entry.name.baseName;
    auto licenseName = bn[0 .. $ - 4];
    return new License(licenseName, cast(string) filteredText.array, false);
}

/**
 * Licensing engine performs preloading and computation of
 * license specifics.
 */
public final class Engine
{

    /**
     * Preload all of our licenses
     */
    void loadFromDirectory(in string directory)
    {
        enforce(directory.exists);
        trace("Preloading license data");

        auto entries = dirEntries(directory, "*.txt", SpanMode.shallow, false).array;
        auto data = taskPool.amap!loadLicense(entries);
        licenses = new LicenseTree();
        licenses.insert(data);
    }

private:

    alias LicenseTree = RedBlackTree!(License*, "a.identifier < b.identifier", false);
    LicenseTree licenses;
}
