# Laptop Optimus GPU Passthrough (Arch Linux Host to Ubuntu SeaBIOS Guest)

This guide documents the process of passing a headless laptop Optimus Nvidia GPU (`3D controller`, GTX 960M/970M) from an Arch Linux host to a QEMU/KVM Ubuntu guest. 

Because laptop Optimus GPUs lack a physical VBIOS chip, and the extracted VBIOS (104 KB) exceeds QEMU's 64 KB ACPI table limit, this setup uses QEMU's `-fw_cfg` interface to pass the ROM alongside a tiny custom ACPI script.

## Phase 1: Host Preparation & GPU Isolation (Arch Linux)

### 1. Enable IOMMU
1. Edit your bootloader configuration to append `intel_iommu=on iommu=pt` to your kernel command line. *(Note: Check your specific bootloader like rEFInd or systemd-boot for the exact file path).*
2. Reboot the host and verify IOMMU groups are populated:
   ```bash
   for g in /sys/kernel/iommu_groups/*; do echo "Group ${g##*/}:"; for d in $g/devices/*; do echo "  $(lspci -nns ${d##*/})"; done; done | grep -B 1 -A 2 -i nvidia
   ```

### 2. Isolate the GPU with `vfio-pci`
1. Identify the PCI ID of your `3D controller` (e.g., `01:00.0`) and its hardware ID (e.g., `10de:xxxx`).
2. Create the VFIO configuration file:
   ```bash
   echo "options vfio-pci ids=10de:xxxx disable_idle_d3=1" | sudo tee /etc/modprobe.d/vfio.conf
   ```
3. Preload the VFIO modules. Edit `/etc/mkinitcpio.conf` and update the modules line:
   ```text
   MODULES=(vfio_pci vfio vfio_iommu_type1)
   ```
4. Rebuild the boot image and reboot:
   ```bash
   sudo mkinitcpio -P && sudo reboot
   ```
5. Confirm the driver is bound (it should output `Kernel driver in use: vfio-pci`):
   ```bash
   lspci -nnk -s 01:00.0
   ```

---

## Phase 2: Extracting the VBIOS

Since `acpi_call` text limits cut off the VBIOS, we use `nouveau` to extract the full 104 KB ROM from the Linux debugfs.

1. Ensure all VMs are shut down.
2. Run these commands to temporarily bind `nouveau`, copy the VBIOS, and re-bind `vfio-pci`:
   ```bash
   sudo modprobe nouveau
   echo 0000:01:00.0 | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind
   echo nouveau | sudo tee /sys/bus/pci/devices/0000:01:00.0/driver_override
   echo 0000:01:00.0 | sudo tee /sys/bus/pci/drivers_probe
   
   # Copy the ROM (replace '1' with your exact folder number if different)
   sudo cp /sys/kernel/debug/dri/1/vbios.rom /var/lib/libvirt/images/optimus.rom
   ```
3. **Important:** The host display will likely freeze when unbinding `nouveau` here. If this happens, perform a safe reboot (via SSH or REISUB).
4. After rebooting, verify the file exists and is approximately 104 KB:
   ```bash
   ls -lh /var/lib/libvirt/images/optimus.rom
   ```

---

## Phase 3: The `fw_cfg` ACPI Injection

To bypass QEMU's 64 KB ACPI size limit, we create a tiny ACPI table that reads the 104 KB ROM from QEMU's `fw_cfg` interface during boot.

1. Create the ACPI Source Language (`.dsl`) script:
   ```bash
   sudo tee /var/lib/libvirt/images/ssdt-rom.dsl > /dev/null <<'EOF'
   DefinitionBlock ("", "SSDT", 1, "CUSTOM", "NVROM", 1)
   {
       External (\_SB_.PCI0.S08_, DeviceObj)
   
       Scope (\_SB_.PCI0.S08_)
       {
           Name (FWIT, 0)
           Name (FWBI, Buffer () { 0 })
   
           OperationRegion (FWIO, SystemIO, 0x0510, 2)
           Field (FWIO, WordAcc, NoLock, Preserve) { FSEL, 16 }
           Field (FWIO, ByteAcc, NoLock, Preserve) { Offset (1), FDAT, 8 }
   
           Method (RBUF, 1, Serialized)
           {
               Local0 = Buffer (Arg0) {}
               Local1 = 0
               While ((Local1 < Arg0))
               {
                   Store (FDAT, Index (Local0, Local1))
                   Local1++
               }
               Return (Local0)
           }
   
           Method (RINT, 0, Serialized)
           {
               If (FWIT) { Return (0) }
               FWIT = 1
               FSEL = 0x0019
               Local0 = ((FDAT << 24) | (FDAT << 16) | (FDAT << 8) | FDAT)
               Local1 = 0
               While ((Local1 < Local0))
               {
                   Local2 = ((FDAT << 24) | (FDAT << 16) | (FDAT << 8) | FDAT)
                   Local3 = ((FDAT << 8) | FDAT)
                   Local4 = FDAT
                   Local4 = FDAT
                   If ((ToString (RBUF (56)) == "opt/com.lion328/nvidia-rom"))
                   {
                       FSEL = Local3
                       CopyObject (RBUF (Local2), FWBI)
                       Break
                   }
                   Local1++
               }
               Return (0)
           }
   
           Method (_ROM, 2, Serialized)
           {
               RINT ()
               If ((Arg0 >= SizeOf (FWBI))) { Return (Buffer (0) {}) }
               Local0 = Arg1
               If (((Arg0 + Local0) > SizeOf (FWBI))) { Local0 = (SizeOf (FWBI) - Arg0) }
               Return (Mid (FWBI, Arg0, Local0))
           }
       }
   }
   EOF
   ```
   *(Note: Ensure `\_SB_.PCI0.S08_` matches the ACPI path of your GPU inside the guest. You can verify this inside the guest with `cat /sys/bus/pci/devices/0000:08:00.0/firmware_node/path`)*

2. Compile it into an `.aml` binary:
   ```bash
   sudo iasl -tc /var/lib/libvirt/images/ssdt-rom.dsl
   ```

---

## Phase 4: Virtual Machine Configuration

1. Attach the `01:00.0` PCI host device to your Ubuntu VM via `virt-manager` (Add Hardware -> PCI Host Device). Do *not* attach the `00:01.0` PCIe bridge.
2. Edit your VM's XML configuration:
   ```bash
   virsh edit <vm-name>
   ```
3. Change the first line to include the QEMU namespace:
   ```xml
   <domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
   ```
4. Add the following block at the very bottom, just above `</domain>`:
   ```xml
   <qemu:commandline>
     <qemu:arg value='-acpitable'/>
     <qemu:arg value='file=/var/lib/libvirt/images/ssdt-rom.aml'/>
     <qemu:arg value='-fw_cfg'/>
     <qemu:arg value='name=opt/com.lion328/nvidia-rom,file=/var/lib/libvirt/images/optimus.rom'/>
   </qemu:commandline>
   ```

---

## Phase 5: Guest Driver Installation

1. Boot the Ubuntu VM.
2. Install the appropriate legacy driver for the Maxwell GPU (branch `580`):
   ```bash
   sudo apt update && sudo apt install -y nvidia-driver-580-server
   sudo reboot
   ```
3. After rebooting, confirm the driver initializes the card successfully:
   ```bash
   nvidia-smi
   ```

---

## How to Undo These Changes

If you ever want to return your Arch host to normal and give the GPU back to the host OS, follow these steps:

1. **Remove VM Hardware:** In `virt-manager`, remove the NVIDIA PCI Host Device from your Ubuntu VM.
2. **Remove QEMU XML Edits:** Run `virsh edit <vm-name>` and delete the entire `<qemu:commandline>` block at the bottom, then remove `xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'` from the top tag.
3. **Delete VFIO Config:** On the Arch host, delete the modprobe file:
   ```bash
   sudo rm -f /etc/modprobe.d/vfio.conf
   ```
4. **Remove Initramfs Hooks:** Open `/etc/mkinitcpio.conf` and remove `vfio_pci vfio vfio_iommu_type1` from the `MODULES=(...)` array.
5. **Rebuild and Reboot:**
   ```bash
   sudo mkinitcpio -P && sudo reboot
   ```
6. **(Optional) Clean up leftover ROM files:**
   ```bash
   sudo rm -f /var/lib/libvirt/images/optimus.rom /var/lib/libvirt/images/ssdt-rom.*
   ```