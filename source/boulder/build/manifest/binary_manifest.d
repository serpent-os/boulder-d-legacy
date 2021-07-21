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

module boulder.build.manifest.binary_manifest;

public import boulder.build.manifest;
import boulder.build.context;
import std.path : buildPath;

import moss.format.binary.archive_header;
import moss.format.binary.payload;
import moss.format.binary.writer;

/**
 * Binary, read-write implementation of the BuildManifest
 */
final class BuildManifestBinary : BuildManifest
{

    @disable this();

    /**
     * Construct a new BuildManifest with the given architecture identifier
     */
    this(const(string) architecture)
    {
        import std.string : format;
        import std.algorithm : substitute;

        /* i.e. manifest.x86_64 */
        fileName = "manifest.%s.bin".format(architecture.substitute!("/", "-"));
    }

    override void recordPackage(const(string) pkgName, ref FileAnalysis[] fileSet)
    {
    }

    override void write() @safe
    {
        import std.algorithm : each;

        auto targetPath = buildContext.outputDirectory.buildPath(fileName);
        auto fp = File(targetPath, "w");
        auto writer = new Writer(fp);
        writer.compressionType = PayloadCompression.None;
        writer.fileType = MossFileType.Database;
        scope (exit)
        {
            writer.close();
        }
        payloads.each!((ref p) => writer.addPayload(p));
        writer.flush();
    }

private:

    Payload[] payloads;
}
