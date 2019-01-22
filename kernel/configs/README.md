## Types of config files

This directory holds config files for the Kata Linux Kernel in two forms:

- As complete config files that can be used as-is.
- A tree of config file 'fragments' in the `fragments` sub-folder, that are
  constructed into a complete config file using the kernel
  `scripts/kconfig/merge_config.sh` script.

## How to use config files

Complete config files must be copied in the kernel source code directory and renamed to `.config`

For example:

```bash
$ cp x86_kata_kvm_4.14.x linux-4.14.22/.config
$ pushd linux-4.14.22
$ make ARCH=x86_64 -j4
```

Alternatively, use the [`build_kernel.sh`](../build-kernel.sh) script to set up the
config file, for example:

```bash
$ ./build-kernel.sh setup
```

The `build_kernel.sh` is also the recommended way to construct `.config` files from the fragments.

Run `./build-kernel.sh help` for more information.

## How to modify config files

Complete config files can be modified either with an editor, or more easily
using the kernel `Kconfig` configuration tools, for example:

```
cp x86_kata_kvm_4.14.x linux-4.14.22/.config
pushd linux-4.14.22
make menuconfig
popd
cp linux-4.14.22/.config x86_kata_kvm_4.14.x
```

Kernel fragments are best constructed using an editor. Tools such as `grep` and
`diff` can help find the differences between two config files to be placed
into a fragment.

If adding config entries for a new subsystem or feature, consider making a new
fragment with an appropriately descriptive name.

The fragment gathering tool perfoms some basic sanity checks, and the `build-kernel.sh` will
fail and report the error in the cases of:

- A duplicate `CONFIG` symbol appearing.
- A `CONFIG` symbol being in a fragment, but not appearing in the final .config
  - which indicates that `CONFIG` variable is not a part of the kernel `Kconfig` setup, which
    can indicate a typing mistake in the name of the symbol.
- A `CONFIG` symbol appearing in the fragments with multiple different values.
