#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <hostname>"
    exit 1
fi

VMNAME=$1
IMAGE_DIR="/var/lib/libvirt/images"
NVRAM_VARS="/var/lib/libvirt/qemu/nvram/${VMNAME}_VARS.fd"
BOOT_VARS="/usr/share/AAVMF/AAVMF_VARS.fd"
BASE_IMAGE="${IMAGE_DIR}/ubuntu20.04-base.qcow2"
TARGET_IMAGE="${IMAGE_DIR}/${VMNAME}.qcow2"
SEED_FOLDER="${IMAGE_DIR}/../cloud-init/${VMNAME}/"
SEED_IMAGE="${SEED_FOLDER}/${VMNAME}-seed.img"

if [ -f "${TARGET_IMAGE}" ]; then
    echo "Error: VM image ${TARGET_IMAGE} already exists."
    echo "Please choose a different hostname or remove the existing image."
    exit 1
fi

# Copy the base image
cp "${BASE_IMAGE}" "${TARGET_IMAGE}"
mkdir -p /var/lib/libvirt/qemu/nvram/
cp "${BOOT_VARS}" "${NVRAM_VARS}"
# Create user-data
cat > /tmp/user-data <<EOF
#cloud-config
hostname: ${VMNAME}
manage_etc_hosts: true

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/ubuntu
    shell: /bin/bash
    ssh_authorized_keys:
      - yourpubkey

ssh_pwauth: false
disable_root: true
chpasswd:
  expire: false

network:
  version: 2
  ethernets:
    ens3: #Here you should make sure you write the interface name your image uses
      dhcp4: true
EOF

# Create meta-data
cat > /tmp/meta-data <<EOF
instance-id: ${VMNAME}
local-hostname: ${VMNAME}
EOF
mkdir -p "${SEED_FOLDER}"
# Generate the seed image
cloud-localds "${SEED_IMAGE}" /tmp/user-data /tmp/meta-data

rm /tmp/user-data
rm /tmp/meta-data

echo "VM image prepared: ${TARGET_IMAGE}"
echo "Seed image created: ${SEED_IMAGE}"
echo "Now you can boot it with virt-install!"


virt-install \
  --name ${VMNAME} \
  --memory 2048 \
  --vcpus 2 \
  --arch aarch64 \
  --os-variant ubuntu20.04 \
  --machine virt \
  --import \
  --disk path=${TARGET_IMAGE},format=qcow2 \
  --disk path=${SEED_IMAGE},device=cdrom,format=raw \
  --network bridge=br0 \
  --graphics none \
  --console pty,target_type=serial \
  --boot loader=/usr/share/AAVMF/AAVMF_CODE.fd,nvram=${NVRAM_VARS},loader.readonly=yes,loader.type=pflash \
  --noautoconsole