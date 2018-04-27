# Packaging scripts

This directory contains useful packaging scripts.

## `configure-hypervisor.sh`

This script generates the official set of QEMU-based hypervisor build
configuration options. All repositories that need to build a hypervisor
from source **MUST** use this script to ensure the hypervisor is built
in a known way since using a different set of options can impact many
areas including performance, memory footprint and security.

Example usage:

```
  $ configure-hypervisor.sh qemu-lite
```

## `apport_hook.py`

This script is a basic hook which will call the cc-collect-data.sh script
when any of the components crashes (runtime, proxy, shim, qemu-lite).
The script output will then be added to the standard Ubuntu bug report
that will get created on launchpad.net.

## `get-image-changes.sh`

This script generates the list of changed packages that are used in Kata
Containers image.  The changes are collected from Kata Linux release notes:

```
https://download.clearlinux.org/releases/XXXX/clear/RELEASENOTES
```

The list of changes will be created from the current image version (defined
in `versions.txt`) to a version provided to the script.

Usage:

```
   $ ./get-image-changes.sh VERSION-TO-UPDATE > changes
   $ cat changes
```

## `kernel_monitor/kernel_monitor.py`

This script fetches the latest kernel information and looks for new LTS releases.
If it finds a new LTS release it sends an email to the selected recipients.

Requirements:

* python3
* python dependencies (see the [requirements file](https://github.com/clearcontainers/packaging/scripts/kernel_monitor/requirements))
* pip
* postfix

Usage:

NOTE: The following commands can be executed if you have a Fedora 27 system that meets all requirements,
and a postfix server running on 127.0.0.1 or localhost.

Install python dependencies:

NOTE: It is strongly recommended to run this script in a Python virtual environment with `virtualenv`.
```
$ cd kernel_monitor
$ virtualenv km
$ source km/bin/activate
$ pip install -r requirements
```

Execute the following script:
```
$ chmod +x kernel_monitor.py
$ ./kernel_monitor.py
```

This sends an email if there is a new LTS release and logs the events to a file.
For more information about how to change the email recipients, the log file name or the
postfix server address, execute the script with `--help` to see the options:
```
$ ./kernel_monitor.py --help
```
