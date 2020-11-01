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

module boulder.build.collector;

import std.path;
import std.file;
import std.algorithm : startsWith;
import moss.format.source.packageDefinition;
import boulder.build.emitter : BuildEmitter;
import boulder.build.context : BuildContext;

/**
 * A CollectionRule simply defines a pattern to match against (glob style)
 * and a priority with which the pattern will be used.
 *
 * Increased priority numbers lead to the rule running before other rules.
 */
package final struct CollectionRule
{
    /**
     * A glob style pattern to match againt
     */
    string pattern = null;

    /**
     * A target name to incorporate, such as "name-devel"
     */
    string target = null;

    /**
     * Priority used to sort the rules
     */
    int priority = 0;

    pure bool match(const(string) inp) @safe
    {
        return (inp == pattern || inp.startsWith(pattern)
                || globMatch!(CaseSensitive.yes)(inp, pattern));
    }
}

/**
 * The BuildCollector is responsible for collecting and analysing the
 * contents of the build root, and assigning packages for each given
 * path.
 *
 * By default, all files will end up in the main package unless explicitly
 * overridden by a pattern.
 */
final struct BuildCollector
{

public:

    /**
     * Begin collection on the given root directory, considered to be
     * the "/" root filesystem of the target package.
     */
    final void collect(ref BuildEmitter em, const(string) rootDir) @system
    {
        import std.algorithm;

        _rootDir = rootDir;

        dirEntries(rootDir, SpanMode.depth, false).each!((ref e) => this.analysePath(em, e));
    }

    /**
     * Return the root directory for our current operational set
     */
    pragma(inline, true) pure final @property string rootDir() @safe @nogc nothrow
    {
        return _rootDir;
    }

    /**
     * Add a priority based rule to the system which can of course be overridden.
     */
    final void addRule(string pattern, string target, uint priority = 0) @safe
    {
        import std.algorithm;

        /* Sort ahead of time */
        rules ~= CollectionRule(pattern, target, priority);
        rules.sort!((a, b) => a.priority > b.priority);
    }

private:

    /**
     * Analyse a given path and start acting on it
     */
    final void analysePath(ref BuildEmitter em, ref DirEntry e) @system
    {
        import std.stdio;
        import std.string : format;
        import std.algorithm;
        import std.range;
        import std.exception : enforce;

        auto targetPath = e.name.relativePath(rootDir);

        /* Ensure full "local" path */
        if (targetPath[0] != '/')
        {
            targetPath = "/%s".format(targetPath);
        }

        auto fullPath = e.name;
        /* Find out whre it goes */
        auto matchingSet = rules.filter!((r) => r.match(targetPath)).takeOne();
        enforce(!matchingSet.empty,
                "analysePath: No matching rule for path: %s".format(targetPath));
        auto matching = matchingSet.front;
        writefln("%s = %s", fullPath, matching.target);

        em.addFile(matching.target, targetPath);
    }

    /**
     * Compute and store the hash for the file
     * We use the dupeStoreHash to ensure all identical files
     * are only added once
     */
    final void storeHash(const(string) p) @system
    {
        auto hash = checkHash(p);
        if (hash in dupeHashStore)
        {
            return;
        }
        dupeHashStore[hash] = p;
    }

    /**
     * Ugly utility to check a hash
     */
    final string checkHash(const(string) path)
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

    string _rootDir = null;
    CollectionRule[] rules;

    /* Store hash -> source path here to only store once */
    string[string] dupeHashStore;
}
