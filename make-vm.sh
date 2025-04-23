#!/bin/bash
set -euo pipefail
trap 'echo "Error on line $LINENO"; exit 1' ERR

if [ $# -ne 2 ]; then
    echo "Usage: $0 <hostname> <IPv4 address>"
    exit 1
fi

VMNAME=$1
IP=$2
IMAGE_DIR="/var/lib/libvirt/images"
NVRAM_VARS="/var/lib/libvirt/qemu/nvram/${VMNAME}_VARS.fd"
BOOT_VARS="/usr/share/AAVMF/AAVMF_VARS.fd"
BASE_IMAGE="${IMAGE_DIR}/focal-server-cloudimg-arm64.img"
TARGET_IMAGE="${IMAGE_DIR}/${VMNAME}.qcow2"
CLOUD_INIT_DIR="/var/lib/libvirt/cloud-init"
SEED_IMAGE="${CLOUD_INIT_DIR}/${VMNAME}-seed.iso"

if [ -f "${TARGET_IMAGE}" ]; then
    echo "Error: VM image ${TARGET_IMAGE} already exists."
    echo "Please choose a different hostname or remove the existing image."
    exit 1
fi

# Copy the base image and resize it
qemu-img convert -O qcow2 ${BASE_IMAGE} ${TARGET_IMAGE}
qemu-img resize ${TARGET_IMAGE} 20G  # Resize to your preferred size

# Prepare NVRAM
mkdir -p /var/lib/libvirt/qemu/nvram/
cp "${BOOT_VARS}" "${NVRAM_VARS}"

# Create cloud-init directories
mkdir -p "${CLOUD_INIT_DIR}"

# Create user-data with a simple password
cat > /tmp/user-data <<EOF
#cloud-config
debug:
  verbose: true

hostname: ${VMNAME}
manage_etc_hosts: true
# Disable the default user creation

users:
  - name: ubuntu         # Use 'ubuntu' as it's the default user
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/ubuntu
    lock_passwd: false
    passwd: '\$6\$qPOK1T3vd6ou5nmH\$oySSiKlsYu1TpuhQ9.aMhR4vTAj8qWkitBsFvekXNFr097xp5hrvI42KyIJ4VXbmc7un1q.CbrW7S3iIfdP45.' #pass, every $ is \$
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHC009y9YIkSeKF/dSygNn2xsacL/LuAJONPXqRvxh3L anton@Over700
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmm9JOa9R4n5E7YftCc6evF97KveacMYAT6CFDOt3Ay anton@Useless_box
chpasswd:
  expire: false

# Allow password authentication for SSH
ssh_pwauth: false
disable_root: false
# Set a custom password for the default ubuntu user

# Network configuration
network:
  version: 2
  ethernets:
    enp1s0:     # Standard interface name, may need adjustment
      #dhcp4: true   # Using DHCP is more reliable for testing
      dhcp4: false
      addresses:
        - ${IP}/24
      gateway4: 192.168.0.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]

# Console setup
bootcmd:
  - echo 'ttyAMA0' >> /etc/securetty
  - echo 'console=ttyAMA0' >> /etc/default/grub
  - echo 'GRUB_TERMINAL="console serial"' >> /etc/default/grub
  - echo 'GRUB_SERIAL_COMMAND="serial --speed=115200"' >> /etc/default/grub

# Additional commands to run after boot
runcmd:
  - sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  - systemctl restart sshd
  - update-grub
  - systemctl enable serial-getty@ttyAMA0.service
  - systemctl start serial-getty@ttyAMA0.service
  # Enable root login on console
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - echo "root:ubuntu" | chpasswd
  # Create a local.conf to ensure serial console is enabled
  - echo 'GRUB_CMDLINE_LINUX="console=tty1 console=ttyAMA0,115200n8"' > /etc/default/grub.d/local.conf
  - update-grub
EOF

# Create meta-data
cat > /tmp/meta-data <<EOF
instance-id: ${VMNAME}
local-hostname: ${VMNAME}
EOF

# Create the cloud-init ISO (NoCloud datasource)
cloud-localds -v "${SEED_IMAGE}" /tmp/user-data /tmp/meta-data

echo "VM image prepared: ${TARGET_IMAGE}"
echo "Cloud-init ISO created: ${SEED_IMAGE}"

# Start the VM
virt-install \
  --name ${VMNAME} \
  --memory 2048 \
  --vcpus 2 \
  --arch aarch64 \
  --os-variant ubuntu22.04 \
  --machine virt \
  --import \
  --disk path=${TARGET_IMAGE},format=qcow2 \
  --disk path=${SEED_IMAGE},device=cdrom \
  --network bridge=br0 \
  --graphics none \
  --console pty,target_type=serial \
  --boot loader=/usr/share/AAVMF/AAVMF_CODE.fd,nvram=${NVRAM_VARS},loader.readonly=yes,loader.type=pflash \
  --noautoconsole

# Clean up
rm /tmp/user-data
rm /tmp/meta-data

echo "VM '${VMNAME}' created successfully."
echo "You can connect to the console with: 'virsh console ${VMNAME}'"
echo "Default login: ubuntu / ubuntu"