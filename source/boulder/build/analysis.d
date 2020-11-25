/*
 * This file is part of boulder.
 *
 * Copyright © 2020 Serpent OS Developers
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

module boulder.build.analysis;

import std.path;
import std.file;
import moss.format.binary.layout : FileType;
import core.sys.posix.sys.stat;

/**
 * CollectionResult gathers all data ahead of time to allow simpler
 * generation of the payloads.
 */
package final struct FileAnalysis
{

package:

    this(const(string) relativePath, const(string) fullPath)
    {
        import std.string : toStringz, format;
        import std.exception : enforce;

        _path = relativePath;
        _fullPath = fullPath;
        auto z = fullPath.toStringz;
        auto ret = lstat(z, &statResult);
        enforce(ret == 0, "CollectionResult: unable to stat() %s".format(fullPath));

        /**
         * Determine underlying file type and decide exactly what to do with
         * it. For most things we just set the type, for regular files we source
         * the hash sum, and for symlinks we read the link itself.
         */
        switch (statResult.st_mode & S_IFMT)
        {
        case S_IFBLK:
            _type = FileType.BlockDevice;
            break;
        case S_IFCHR:
            _type = FileType.CharacterDevice;
            break;
        case S_IFDIR:
            _type = FileType.Directory;
            break;
        case S_IFIFO:
            _type = FileType.Fifo;
            break;
        case S_IFLNK:
            _type = FileType.Symlink;
            _data = fullPath.readLink();
            break;
        case S_IFREG:
            _type = FileType.Regular;
            _data = checkHash(fullPath);
            break;
        case S_IFSOCK:
            _type = FileType.Socket;
            break;
        default:
            _type = FileType.Unknown;
            break;
        }
    }

    /**
     * Return the underlying filetype
     */
    pure final FileType type() @safe @nogc nothrow
    {
        return _type;
    }

    /**
     * Return the data (symlink target or hash
     */
    pure final const(string) data() @safe
    {
        import std.exception : enforce;

        enforce(type == FileType.Regular || type == FileType.Symlink,
                "CollectionResult.data() only supported for symlinks + regular files");
        return _data;
    }

    /**
     * Return true if this is a relative symlink
     */
    pure final bool relativeSymlink() @safe
    {
        import std.string : startsWith;

        return !data.startsWith("/");
    }

    /**
     * Return the fully resolved symlink
     */
    pure final const(string) symlinkResolved() @safe
    {
        import std.exception : enforce;

        enforce(type == FileType.Symlink,
                "CollectionResult.symlinkResolved() only supported for symlinks");

        auto dirn = path.dirName;
        return dirn.buildPath(data.relativePath(dirn));
    }

    /**
     * Return the target filesystem path
     */
    pure final const(string) path() @safe @nogc nothrow
    {
        return _path;
    }

    /**
     * Return the full path to the file on the host disk
     */
    pure final const(string) fullPath() @safe @nogc nothrow
    {
        return _fullPath;
    }

private:

    /**
     * Ugly utility to check a hash
     */
    final string checkHash(const(string) path) @trusted
    {
        import std.stdio;
        import std.digest.sha;
        import std.string : toLower;

        auto sha = new SHA256Digest();
        auto input = File(path, "rb");
        foreach (ubyte[] buffer; input.byChunk(16 * 1024 * 1024))
        {
            sha.put(buffer);
        }
        return toHexString(sha.finish()).toLower();
    }

    FileType _type = FileType.Unknown;
    string _data = null;
    string _path = null;
    string _fullPath = null;
    stat_t statResult;
}
