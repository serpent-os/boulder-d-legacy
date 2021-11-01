/*
 * This file is part of boulder.
 *
 * Copyright © 2020-2021 Serpent OS Developers
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

module boulder.build.controller;

import moss.core.download.store;
import boulder.build.builder;
import boulder.build.context;

import std.exception : enforce;
import std.file : exists;
import std.path : dirName, absolutePath;
import std.string : format, endsWith;
import moss.format.source.spec;

/**
 * The BuildController is responsible for the main execution cycle of Boulder,
 * and as such, the main entry point for actual builds. It should be noted that
 * as the build process can be one that hangs execution, it is run on a separate
 * thread.
 */
public final class BuildController
{

    /**
     * Construct a new BuildController
     */
    this()
    {
        downloadStore = new DownloadStore(StoreType.User);
    }

    /**
     * Request that we begin building the given path
     */
    void build(const(string) path)
    {
        enforce(path.exists,
                "BuildController.build(): Cannot build %s as it does not exist".format(path));
        enforce(path.endsWith(".yml"),
                "BuildController.build(): Path does not look like a valid YML file: %s".format(
                    path));

        if (builder !is null)
        {
            builder.destroy();
        }

        /* Set up the new builder */
        auto s = new Spec(File(path, "r"));
        s.parse();

        buildContext.spec = s;
        buildContext.specDir = path.dirName.absolutePath;

        builder = new Builder();

        import std.stdio : writeln;

        writeln("TODO: Build");
    }

private:

    DownloadStore downloadStore = null;
    Builder builder = null;
}
