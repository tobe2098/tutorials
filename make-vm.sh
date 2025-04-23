#!/bin/bash

set -euo pipefail
trap 'echo "Error on line $LINENO"; exit 1' ERR

if [ $# -ne 1 ]; then
    echo "Usage: $0 <hostname>"
    exit 1
fi

VMNAME=$1
IMAGE_DIR="/var/lib/libvirt/images"
NVRAM_VARS="/var/lib/libvirt/qemu/nvram/${VMNAME}_VARS.fd"
BOOT_VARS="/usr/share/AAVMF/AAVMF_VARS.fd"
BASE_IMAGE="${IMAGE_DIR}/seed.qcow2"
TARGET_IMAGE="${IMAGE_DIR}/${VMNAME}.qcow2"
SEED_FOLDER="var/lib/libvirt/cloud-init/${VMNAME}"
SEED_IMAGE="${SEED_FOLDER}/${VMNAME}-seed.img"
PASSWORD='$6$Qt0ufFgJbq7CH7Ml$Xs/Kh0kQ2wrWtwallMD3uIhpXoFNpw3eVrvegkqDfXPWY3gA6iKii8VGDepttLJywuoDv7GQsHrPqEhOZo450/'
if [ -f "${TARGET_IMAGE}" ]; then
    echo "Error: VM image ${TARGET_IMAGE} already exists."
    echo "Please choose a different hostname or remove the existing image."
    exit 1
fi

# Copy the base image
qemu-img convert -c -O qcow2 ${BASE_IMAGE} ${TARGET_IMAGE}
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
    lock_passed: false
    passwd: ${PASSWORD}
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHC009y9YIkSeKF/dSygNn2xsacL/LuAJONPXqRvxh3L anton@Over700
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmm9JOa9R4n5E7YftCc6evF97KveacMYAT6CFDOt3Ay anton@Useless_box

ssh_pwauth: false
disable_root: true
chpasswd:
  expire: false

network:
  version: 2
  ethernets:
    enp1s0: #Here you should make sure you write the interface name your image uses
      #dhcp4: true
      dhcp4: false
      addresses:
        - 192.168.0.50/24
      gateway4: 192.168.0.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]

bootcmd:
  - echo 'ttyAMA0' >> /etc/securetty
  - systemctl enable serial-getty@ttyAMA0.service
# Ensure serial console is properly set up
runcmd:
  - [ sh, -c, 'grep -q console=ttyAMA0 /etc/default/grub || sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=console=ttyAMA0 /" /etc/default/grub' ]
  - update-grub

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