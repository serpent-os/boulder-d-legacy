/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * mason.build.manifest.binary_manifest
 *
 * Document binary build information
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module mason.build.manifest.binary_manifest;

public import mason.build.manifest;

import moss.format.binary.archive_header;
import moss.format.binary.payload;
import moss.format.binary.writer;
import std.string : format;
import std.algorithm : substitute;
import mason.build.context;
import std.array : join;

/**
 * Binary, read-write implementation of the BuildManifest
 */
final class BuildManifestBinary : BuildManifest
{

    @disable this();

    /**
     * Construct a new BuildManifest with the given architecture identifier
     */
    this(const(string) architecture) @safe
    {
        /* i.e. manifest.x86_64 */
        fileName = "manifest.%s.bin".format(architecture.substitute!("/", "-"));
    }

    override void recordPackage(const(string) pkgName, scope MetaPayload mp, scope LayoutPayload lp) @safe
    {

    }

    override void write() @safe
    {
        import std.algorithm : each;

        auto targetPath = join([buildContext.outputDirectory, fileName], "/");
        auto fp = File(targetPath, "w");
        auto writer = new Writer(fp);
        writer.compressionType = PayloadCompression.Zstd;
        writer.fileType = MossFileType.BuildManifest;
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
