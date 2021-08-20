#!/usr/bin/env bash
set -exuo pipefail

function cleanup() {
  if [ $? -ne 0 ]; then
    rm -f "${CUSTOMIZE_IMAGE_PATH}"
  fi

  rm -rf "${CLOUD_INIT_ISO}"
  virsh destroy "${DOMAIN_NAME}" || true
  virsh undefine "${DOMAIN_NAME}" || true
}

function wait_for_vm_state() {
  count=0
  retries=100
  until [[ $(virsh list --state-$1 --name |grep . ) =~ $DOMAIN_NAME || $count -gt $retries ]]; do
    sleep 5
    count=$((count + 1))
  done
  if [[ $count -gt $retries ]]; then
    echo "Failed to find VM '$DOMAIN_NAME' in $1 state after waiting for "`expr $count \* $retries` "seconds"
    return 1
  else
    echo "done"
  fi
}

SOURCE_IMAGE_PATH=$1
OS_VARIANT=$2
CUSTOMIZE_IMAGE_PATH=$3
CLOUD_CONFIG_PATH=$4

readonly DOMAIN_NAME="provision-vm"
readonly CLOUD_INIT_ISO="cloudinit.iso"

trap 'cleanup' EXIT SIGINT

# Create cloud-init user data ISO
cloud-localds "${CLOUD_INIT_ISO}" "${CLOUD_CONFIG_PATH}"

echo "Customize image by booting a VM with
 the image and cloud-init disk
 press ctrl+] to exit"
virt-install \
  --memory 2048 \
  --vcpus 2 \
  --name $DOMAIN_NAME \
  --disk "${SOURCE_IMAGE_PATH}",device=disk \
  --disk "${CLOUD_INIT_ISO}",device=cdrom \
  --os-type Linux \
  --os-variant "${OS_VARIANT}" \
  --virt-type kvm \
  --graphics none \
  --network default \
  --import \
  --noautoconsole

wait_for_vm_state "shutoff"

# Stop VM
virsh destroy $DOMAIN_NAME || true

# Prepare VM image
virt-sysprep -d $DOMAIN_NAME --operations machine-id,bash-history,logfiles,tmp-files,net-hostname,net-hwaddr

# Remove VM
virsh undefine $DOMAIN_NAME

# Convert image
qemu-img convert -c -O qcow2 "${SOURCE_IMAGE_PATH}" "${CUSTOMIZE_IMAGE_PATH}"
