### boulder

This repository contains the `boulder` tool, which is used to produce
`.stone` binary packages from a `stone.yml` source definition file.

It is currently the main focus area and is subject to rapid iteration.

### Building

    git submodule update --init --recursive
    ./scripts/build.sh

### Running

    ./bin/boulder build stone.yml
