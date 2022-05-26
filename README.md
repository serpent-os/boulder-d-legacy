### boulder

This repository contains the `boulder` tool, which is used to produce
`.stone` binary packages from a `stone.yml` source definition file.

#### Prerequisites

`boulder` (and its own dependencies) depends on a couple of system libraries
and development headers, including (in fedora package names format):

- `cmake`, `meson` and `ninja`
- `libcurl` and `libcurl-devel`
- `libzstd` and `libzstd-devel`
- `xxhash-libs` and `xxhash-devel`
- `moss` (build prior to building `boulder`)
- `moss-container` (build after `moss` and prior to boulding `boulder`)

### Building

    meson build/
    meson compile -C build/

### Running

    sudo build/boulder build stone.yml
