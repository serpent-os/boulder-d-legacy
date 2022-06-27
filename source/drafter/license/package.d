/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * drafter.license
 *
 * Definition of the `License` type
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module drafter.license;

public import drafter.license.engine;

/**
 * A License as found in the SPDX data set
 */
public struct License
{
    /**
     * SPDX 3.x identifier for the license
     */
    string identifier;

    /**
     * Plain text body for the license
     * We drop all whitespace + convert to lower case.
     */
    string textBody;

    /**
     * True if the license is deprecated by SPDX
     */
    bool isDeprecated;
}
