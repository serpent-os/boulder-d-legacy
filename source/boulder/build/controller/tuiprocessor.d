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

module boulder.build.controller.tuiprocessor;

import moss.ansi;
import moss.jobs;

/**
 * TUIProcessor drives an ANSI Window with fancy status
 */
public final class TUIProcessor : SystemProcessor
{

    /**
         * Construct a new TUIProcessor
         */
    this()
    {
        super("tuiProcessor", ProcessorMode.Main);

        mainWindow = new Window();

        /* Sort out the download boxes. */
        auto boxDownload = new Box(BoxOrientation.Vertical);
        foreach (i; 0 .. 4)
        {
            downloadProgress[i] = new ProgressBar();
            boxDownload.add(downloadProgress[i]);
        }
        mainWindow.add(boxDownload);
    }

    /**
         * Receive updates from elsewhere..
         */
    override bool allocateWork()
    {
        return false;
    }

    /**
         * Draw the work
         */
    override void performWork()
    {
        mainWindow.draw();
    }

    /**
         * Sync the work.
         */
    override void syncWork()
    {

    }

private:

    Window mainWindow;
    ProgressBar[4] downloadProgress;
}
