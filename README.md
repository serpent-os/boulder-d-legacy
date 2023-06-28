# boulder

This repository contains the `boulder` tool, which is used to produce
`.stone` binary packages from a `stone.yml` source definition file.

`boulder` builds stones in an isolated environment (that is, a namespace-based container). The companion application `/usr/libexec/boulder/container` is responsible of creating, running, and destroying this environment. The companion application is launched by `boulder` itself and that is the only intended and supported use case.

## Prerequisites

`boulder` (and its own dependencies) depends on a couple of system libraries
and development headers, including (in Fedora package names format):

- `cmake`, `meson` and `ninja`
- `libcurl` and `libcurl-devel`
- `libzstd` and `libzstd-devel`
- `xxhash-libs` and `xxhash-devel`
- `moss` (runtime dependency, build it prior to building `boulder`)

## Cloning

Remember to add the `--recurse-submodule` argument (for serpent-style commit hook, `update-format.sh` and editorconfig settings).

## Building

- With Meson:
    ```bash
    meson setup --prefix=/usr build
    meson compile -C build
    sudo meson install -C build
    ```
- With DUB:
    ```bash
    dub build boulder
    dub build boulder:container
    ```

## Running

    sudo boulder build stone.yml

# container

Container is a rootless container manager based on Linux namespace. It is akin to a stripped-down Podman.

It works by creating a base directory owned by proper UID and GID, which correspond to the user internal to the container. This base directory is read/only except when upgrading it with the dedicated command, to cache the latest package releases. When running a confined command (that is, usually, when boulder builds a package), an OverlayFS instance is mounted in a unique path, on top of the base directory, ensuring that multiple containers can run simultaneously without conflicting with each other.
