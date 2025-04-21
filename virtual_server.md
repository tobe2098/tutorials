# Setting up your own Ubuntu virtual machine server
## Dependencies
```
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager bridge-utils -y
sudo apt install docker.io #Or podman
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
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
## Creating the machine
```
sudo virt-install \
  --name ubuntu2404 \
  --ram 4096 \
  --vcpus 2 \
  --os-variant ubuntu24.04 \
  --location /var/lib/libvirt/images/isos/ubuntu-24.04.2-live-server-amd64.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
  --disk size=20,path=/var/lib/libvirt/images/ubuntu2404.qcow2,format=qcow2 \
  --network network=default \
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
  --network network=default \
  --graphics none \
  --console pty,target_type=serial \
  --extra-args="console=ttyS0,115200n8"
  ```
  Then go over the steps

Make sure /etc/default/grub on the VM contains:
```
GRUB_CMDLINE_LINUX="console=ttyS0,115200n8"
sudo update-grub
```