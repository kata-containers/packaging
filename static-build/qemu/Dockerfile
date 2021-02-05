from ubuntu:20.04

ARG QEMU_REPO
# commit/tag/branch
ARG QEMU_VERSION
ARG QEMU_TARBALL
ARG PREFIX

WORKDIR /root/qemu
RUN apt-get update && apt-get upgrade -y
RUN apt-get --no-install-recommends install -y \
	    apt-utils \
	    autoconf \
	    automake \
	    bc \
	    bison \
	    ca-certificates \
	    cpio \
	    flex \
	    gawk \
	    libaudit-dev \
	    libblkid-dev \
	    libcap-dev \
	    libcap-ng-dev \
	    libdw-dev \
	    libelf-dev \
	    libffi-dev \
	    libglib2.0-0 \
	    libglib2.0-dev \
	    libglib2.0-dev git \
	    libltdl-dev \
	    libmount-dev \
	    libpixman-1-dev \
	    libpmem-dev \
	    libseccomp-dev \
	    libseccomp2 \
	    libselinux1-dev \
	    libtool \
	    make \
	    pkg-config \
	    python \
	    python-dev \
	    rsync \
	    zlib1g-dev

RUN cd  .. && git clone "${QEMU_REPO}" qemu
RUN git checkout "${QEMU_VERSION}"
RUN git clone https://github.com/qemu/capstone.git capstone
RUN git clone https://github.com/qemu/keycodemapdb.git ui/keycodemapdb

ADD scripts/configure-hypervisor.sh /root/configure-hypervisor.sh
ADD qemu /root/kata_qemu
ADD scripts/apply_patches.sh /root/apply_patches.sh

RUN stable_branch=$(cat VERSION | awk 'BEGIN{FS=OFS="."}{print $1 "." $2 ".x"}') && \
	/root/apply_patches.sh "/root/kata_qemu/patches/${stable_branch}"

RUN PREFIX="${PREFIX}" /root/configure-hypervisor.sh -s kata-qemu | xargs ./configure \
	--with-pkgversion=kata-static

RUN make -j$(nproc)
RUN make install DESTDIR=/tmp/qemu-static

RUN make -j$(nproc) virtiofsd
RUN chmod +x virtiofsd && mv virtiofsd "/tmp/qemu-static/${PREFIX}/bin/"

RUN cd /tmp/qemu-static && tar -czvf "${QEMU_TARBALL}" *
