# Linux\* container kernel

This directory contains the sources to update rpm specfiles and debian source
control files to generate ``linux-container``, the kernel needed to boot 
 Kata Containers.

With these files we generated Fedora and Ubuntu packages for this component.

``./update_kernel.sh [VERSION]``


This script will generate and update sources to create ``linux-container``
packages.

  * linux-container.spec
  * lnux-container_X.X.XX-XX.dsc

By default, the script will get the latest 4.14 longterm kernel version from
https://www.kernel.org. As an optional parameter you can pass any Linux
``VERSION`` to the script and it will generate the respective packages.

## Open Build Service

The script has two OBS related variables. Using them, the CI can push changes
to the [OBS website](https://build.opensuse.org/).

Environment variable | Default value
---------------------|--------------
``OBS_PUSH``           | **false**
``OBS_CC_KERNEL_REPO`` | **home:clearlinux:preview:clear-containers-staging/linux-container**

To push your changes and trigger a new build of the runtime to the OBS repo,
set the variables in the environment running the script before calling
``update_runtime.sh`` as follows:

```bash
export OBS_PUSH=true
export OBS_CC_KERNEL_REPO=home:patux:clear-containers-2.1/linux-container

./update_kernel.sh [VERSION]
```

## Update Sequence

To update the  Kata Containers kernel the next sequence is follow

     ┌─────────────────────────┐                   ┌───┐          ┌─────────────────────┐      ┌─────────────────────────┐
     │clearcontainers/packaging│                   │OBS│          │clearcontainers/linux│      │clearcontainers/osbuilder│
     └────────────┬────────────┘                   └─┬─┘          └──────────┬──────────┘      └──────────┬──────────────┘
                  ────┐                              │                       │                            │
                      │ Send PR for kernel changes   │                       │                            │
                      │ bump release file            │                       │                            │
                  <───┘                              │                       │                            │
                  │                                  │                       │                            │
                  │                                  │                       │Used by ci to test kernel   │
                  │                                  │                       │before create packages      │
                  │                                  │                       │ vX.Y.ZZ-{release}.container-binaries.tar.gz
                  │                                  │                       │                            │
                  │                                  │                       │                            │
                  │                                  │                       │               Used by osbuilder to create
                  │                                  │                       │               a custom kernel
                  │─────────────────────────────────────────────────────────>│ vX.Y.ZZ-{release}.container.tar.gz
                  │                                  │                       │──────────────────────────> │           
                  │                                  │                       │                            │           
                  │     Test next build packagerelease                       │                            │           
                  │─────────────────────────────────>│                       │                            │           
                  │                                  │                       │                            │           
                  │            Build OK              │                       │                            │           
                  │<─────────────────────────────────│                       │                            │           
                  │                                  │                       │                            │           
                  ────┐                              │                       │                            │           
                      │ Send PR of new kernel package release                │                            │           
                  <───┘                              │                       │                            │           
                  │                 Update with new release                  │                            │
                  │                                  │                       │                            │           
     ┌────────────┴────────────┐                   ┌─┴─┐          ┌──────────┴──────────┐      ┌──────────┴──────────────┐
     │clearcontainers/packaging│                   │OBS│          │clearcontainers/linux│      │clearcontainers/osbuilder│
     └─────────────────────────┘                   └───┘          └─────────────────────┘      └─────────────────────────┘

## Send PR of new kernel release ##

For a new kernel release is need to update the file `release` from this
directory. The release number needs to be incremented for each new
release. It is recommended to update do a version bump for each PR that
changes the kernel version, patches or configuration.
