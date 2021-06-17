### boulder

This repository contains the `boulder` tool, which is used to produce
`.stone` binary packages from a `stone.yml` source definition file.

### Building

    git submodule update --init --recursive
    ./scripts/build.sh

### Running

    ./bin/boulder build stone.yml
