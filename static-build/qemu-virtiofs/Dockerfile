from ubuntu:20.04

ARG QEMU_VIRTIOFS_REPO
# commit/tag/branch
ARG QEMU_VIRTIOFS_TAG
ARG QEMU_TARBALL
ARG PREFIX

WORKDIR /root/qemu-virtiofs
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
	    pkg-config \
	    python \
	    python-dev \
	    rsync \
	    seccomp \
	    zlib1g-dev

RUN cd  .. && git clone "${QEMU_VIRTIOFS_REPO}" qemu-virtiofs
RUN git checkout "${QEMU_VIRTIOFS_TAG}"

ADD scripts/configure-hypervisor.sh /root/configure-hypervisor.sh
ADD qemu /root/kata_qemu
ADD scripts/apply_patches.sh /root/apply_patches.sh

# Apply experimental specific patches
# Patches to quick fix virtiofs fork
ENV VIRTIOFS_PATCHES_DIR=/root/kata_qemu/patches/${QEMU_VIRTIOFS_TAG}/
RUN /root/apply_patches.sh ${VIRTIOFS_PATCHES_DIR}
# Apply the stable branch patches
RUN stable_branch=$(cat VERSION | awk 'BEGIN{FS=OFS="."}{print $1 "." $2 ".x"}') && \
        /root/apply_patches.sh "/root/kata_qemu/patches/${stable_branch}"

RUN PREFIX="${PREFIX}" /root/configure-hypervisor.sh -s kata-qemu | sed -e 's|--disable-seccomp||g' | xargs ./configure \
	--with-pkgversion=kata-static

RUN make -j$(nproc)
RUN make -j$(nproc) virtiofsd
RUN make install DESTDIR=/tmp/qemu-virtiofs-static
RUN mv /tmp/qemu-virtiofs-static/"${PREFIX}"/bin/qemu-system-x86_64 /tmp/qemu-virtiofs-static/"${PREFIX}"/bin/qemu-virtiofs-system-x86_64
RUN chmod +x virtiofsd && mv virtiofsd "/tmp/qemu-virtiofs-static/${PREFIX}/bin/virtiofsd-experimental"
RUN cd /tmp/qemu-virtiofs-static && tar -czvf "${QEMU_TARBALL}"  *
