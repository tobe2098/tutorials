# Setting up your own Ubuntu virtual machine server
## Dependencies
```
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager bridge-utils -y
sudo apt install docker.io #Or podman
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
sudo apt install qemu-efi-aarch64 #If you are Rpi4 or above, you have no UEFI files
```
## Network setup (bridge, optional)
```
nmcli con show
```
Add a new bridge:
```
nmcli con add ifname br0 type bridge con-name br0
```
Create a slave interface:
```
nmcli con add type bridge-slave ifname eth0 master bridge-br0
```
Turn on br0:
```
nmcli con up bridge-br0
```
Optionally, disable spanning-tree protocol
```
nmcli con modify br0 bridge.stp no
```

Then, create `/tmp/br0.xml` with:
```xml []
<network>
  <name>br0</name>
  <forward mode="bridge"/>
  <bridge name="br0" />
</network>
```
And then 
```
virsh net-define /tmp/br0.xml
virsh net-start br0
virsh net-autostart br0
virsh net-list --all
```

After that, you have to set it up in the cloud image (if you are using it):
```
sudo apt install cloud-image-utils
# ~/cloud-init/server1/user-data
#cloud-config
hostname: seed
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
chpasswd:
  expire: false

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/ubuntu
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMmm9JOa9R4n5E7YftCc6evF97KveacMYAT6CFDOt3Ay anton@Useless_box

network:
  version: 2
  ethernets:
    ens3:
      dhcp4: true
#~/cloud-init/server1/meta-data
instance-id: seed
local-hostname: seed
```
Then
```
cloud-localds /var/lib/libvirt/images/server1-seed.img user-data meta-data
```
Also set up the `iptables` rules for IP traffic:
```
sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
sudo iptables -A INPUT -i br0 -p udp -m udp --dport 67 -j ACCEPT
sudo iptables -A INPUT -i br0 -p udp -m udp --dport 53 -j ACCEPT
sudo iptables -A INPUT -i br0 -p tcp -m tcp --dport 53 -j ACCEPT
```
Then make the changes permanent:
```
sudo apt-get install iptables-persistent
```
## Creating the machine without script (DEPRECATED)
These are some of the options. You will need an `.iso`, and 
```
sudo virt-install \
  --name ubuntu2404 \
  --ram 4096 \
  --vcpus 2 \
  --os-variant ubuntu24.04 \
  --location /var/lib/libvirt/images/isos/ubuntu-24.04.2-live-server-amd64.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
  --disk size=20,path=/var/lib/libvirt/images/ubuntu2404.qcow2,format=qcow2 \
  --network network=br0 \
  --graphics none \
  --console pty,target_type=serial \
  --extra-args="console=ttyS0,115200n8"
  ```
  ```
sudo virt-install \
  --name ubuntu200 \
  --ram 2048 \
  --vcpus 2 \
  --os-variant ubuntu20.04 \
  --location /var/lib/libvirt/isos/ubuntu-20.04.5-live-server-arm64.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
  --disk size=20,path=/var/lib/libvirt/images/ubuntu200.qcow2,format=qcow2 \
  --network network=br0 \
  --graphics none \
  --console pty,target_type=serial \
  --extra-args="console=ttyS0,115200n8"
  ```
  Then go over the steps
For Rpi:
```
virt-install \
  --name ubuntu200 \
  --ram 2048 \
  --vcpus 2 \
  --arch aarch64 \
  --machine virt \
  --location /var/lib/libvirt/isos/ubuntu-20.04.5-live-server-arm64.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
  --disk size=20,path=/var/lib/libvirt/images/ubuntu200.qcow2,format=qcow2 \
  --network network=br0 \
  --graphics none \
  --console pty,target_type=serial \
  --boot loader=/usr/share/AAVMF/AAVMF_CODE.fd,nvram=/var/lib/libvirt/qemu/nvram/ubuntu200_VARS.fd,loader.readonly=yes,loader.type=pflash \
  --extra-args="console=ttyS0,115200n8" \
  --noautoconsole #Either or
  ```

After copying the AAVMF_VARS.fd to the location in the command.

Or even better, use a ubuntu cloud image, download it and directly:
```
virt-install \
  --name ubuntutest \
  --ram 2048 \
  --vcpus 2 \
  --osinfo
  --arch aarch64 \
  --machine virt \
  --disk path=/var/lib/libvirt/images/focal-server-cloudimg-arm64.img,format=qcow2 \
  --network network=br0 \
  --graphics none \
  --console pty,target_type=serial \
  --boot loader=/usr/share/AAVMF/AAVMF_CODE.fd,nvram.template=/var/lib/libvirt/qemu/nvram/ubuntu200.fd,loader.readonly=yes,loader.type=pflash \
  --noautoconsole

```



## Optimized route
(Assuming you have set up the [bridge](./virtual_server.md#network-setup-bridge-optional))
Start by downloading a cloud server image : `focal-server-cloudimg-arm64.img`

<!-- Convert the image to `.qcow2`:
```
qemu-img convert -f raw -O qcow2 ubuntu-20.04-server-cloudimg-arm64.img /var/lib/libvirt/images/ubuntu20.04-base.qcow2
```
Resize (optional):
```
qemu-img resize /var/lib/libvirt/images/ubuntu20.04-base.qcow2 20G
``` -->
We will use that as a base. Now we clone it:
```
qemu-img convert -c -O qcow2 focal-server-cloudimg-arm64.img seed.qcow2
```

Install the cloud-image-utils

```
sudo apt install cloud-image-utils
```

Create a dummy `seed.img` with a minimal `user-data` (Look [here](./seed-user-data), use only for testing the pipeline):

```
cloud-localds /var/lib/libvirt/cloud-init/seed/seed.img user-data
```
Get your hashed admin password with `mkpasswd --method=SHA-512` from `whois` package. Put the hash in the [script](./make-vm.sh), but make sure to singl-quote(`'pass'`) it and escape every `$`:`\$`.

Use the script to duplicate the `.qcow2` and create the cloud image with custom hostname and automatically `virt-install` it (takes very long to run bc of `.qcow2` duplication with compression):
```
./make-vm.sh hostname
```
Ready to ssh in and use. If you want to log in, you may need to reboot the vm. You can `autostart` it with `virsh`. 


## Useful commands

```
virsh undefine vmname --nvram --remove-all-storage --snapshots-metadata
```