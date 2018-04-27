# cc-proxy

This directory contains the sources to create rpm spec files and Debian* source
control files to create the  Kata Containers proxy: ``cc-proxy``.

To generate the Fedora* and Ubuntu* packages for this component enter:

``./update_proxy.sh [VERSION]``

The ``VERSION`` parameter is optional. The parameter can be a tag, a branch,
or a GIT hash.

If the ``VERSION`` parameter is not specified, it will be taken from the
top-level ``versions.txt`` file.

This script updates the sources to create the following ``cc-proxy`` files:

  * cc-proxy.dsc
  * cc-proxy.spec
  * debian.*
