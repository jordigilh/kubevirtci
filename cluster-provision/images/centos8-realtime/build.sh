#!/bin/bash

SCRIPT_DIR="$(
    cd "$(dirname "$BASH_SOURCE[0]")"
    pwd
)"

CENTOS_VERSION="8-stream"
ARCH="x86_64"
IMAGE_FILENAME="CentOS-Stream-GenericCloud-8-20210603.0.x86_64.qcow2"
curl -o $SCRIPT_DIR/$IMAGE_FILENAME https://cloud.centos.org/centos/$CENTOS_VERSION/$ARCH/images/$IMAGE_FILENAME
virt-customize --format qcow2 -a $SCRIPT_DIR/$IMAGE_FILENAME --install cloud-init,kernel-rt --memsize 3072 --hostname centos8-realtime --selinux-relabel --root-password password:centos8 --run-command 'dnf install -y yum-utils' --run-command 'yum-config-manager --enable rt' --run-command 'dnf install -y tuned-profiles-realtime' --run-command 'echo -e "isolated_cores=0,1,2\nisolate_managed_irq=Y" >/etc/tuned/realtime-virtual-guest-variables.conf' --firstboot-command 'tuned-adm profile realtime-virtual-guest'
pushd .
cd $SCRIPT_DIR
cat <<EOF >Dockerfile
FROM scratch
ADD $IMAGE_FILENAME /disk/
EOF
docker build . -t quay.io/jordigilh/centos8-realtime:latest 
popd