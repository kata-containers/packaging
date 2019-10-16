FROM centos/systemd
ARG KUBE_ARCH=amd64
ARG KATA_ARTIFACTS=./kata-static.tar.xz

COPY ${KATA_ARTIFACTS} .

RUN \
yum install -y epel-release && \
yum install -y bzip2 jq && \
mkdir -p /opt/kata-artifacts && \
tar xvf ${KATA_ARTIFACTS} -C /opt/kata-artifacts/ && \
chown -R root:root /opt/kata-artifacts/

RUN \
curl -Lso /bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/${KUBE_ARCH}/kubectl && \
chmod +x /bin/kubectl

COPY scripts /opt/kata-artifacts/scripts
RUN \
ln -s /opt/kata-artifacts/scripts/kata-deploy-docker.sh /usr/bin/kata-deploy-docker && \
ln -s /opt/kata-artifacts/scripts/kata-deploy.sh /usr/bin/kata-deploy
