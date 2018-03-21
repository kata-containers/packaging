FROM opensuse:leap

# Get OBS client, plugins and dependencies
RUN zypper -n install osc-plugin-install vim curl bsdtar git sudo pcre-tools
RUN curl -OkL https://download.opensuse.org/repositories/openSUSE:Tools/openSUSE_42.3/openSUSE:Tools.repo
RUN zypper -n addrepo openSUSE:Tools.repo
RUN zypper --gpg-auto-import-keys refresh
RUN zypper -n install build \
    obs-service-tar_scm \
    obs-service-verify_file \
    obs-service-obs_scm \
    obs-service-recompress \
    obs-service-download_url

# Set Go environment
RUN curl -OL https://dl.google.com/go/go1.9.5.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.9.5.linux-amd64.tar.gz

# Local build dependencies
RUN zypper -n install make gcc yum xz
