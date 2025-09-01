# LUKS2 + BTRFS + UBUNTU 24.04 SETUP
This guide is focused around Ubuntu, although the same can be achieved with any other distro by simply changing how the `/boot` and `/boot/efi` partitions. The objective is to end up with a LUKS2-encrypted disk using an `argon2` key derivation function, while having a `btrfs` filesystem with our root within a subvolume.

## Step 1: Creating the installation
The first step consists of creating the partitions and files that will later constitute our entire system. In this tutorial the chosen distro is `Ubuntu 24.04.03`, but the same can be achieved in any other distro as long as `/boot` and `/boot/efi` are separate partitions from `/`.
### Update
First, boot in the machine with a Ubuntu live USB (can be simply created by downloading the `.iso` and  `dd`ing into a USB). For good measure, update the software once you have booted in the live OS:
```
sudo apt update && sudo apt upgrade -y
```
And if not installed, install `btrfs-progs cryptsetup`.
### Ubuntu installer
Follow the instructions of the installer and choose your preferred installation options up to the point where the filesystem and partitions are chosen for the installation. There, choose `"Manual installation"`.
### Partitions
Create a new partition table on your disk, and choose it on the bottom left for the booting partition (`/boot/efi` and `FAT32`, which should be around 1 GB in size). Then, create a new partition of roughly 1-2 GB, `ext4` and set the mountpoint to `/boot`. Then the remainder can be split between swap and `btrfs` to your liking.

Then complete the installation process, choosing the `btrfs` partition for the Ubuntu installation.
### Backup the installation
Depending on the live OS, the installation may be already mounted at `/target`, but if not, mount the `btrfs` partition at `/mnt/root`, and then the `/boot` partition at `/mnt/root/boot`, then the `efi` partition at `/mnt/root/boot/efi`. The booting partitions will not be touched, so you do not have to mount them and copy them if you do not want to, but I find it better this way, in case you make a mistake.
Then `rsync` all the contents to another disk. Mount it at `/mnt/disk`. It does not have to be `btrfs` as far as I know.

## Step 2: Setting up the infrastructure
In this step we set everything up exactly how we want it, but without files or booting. From now on everything should be independent of your distro.

### Encrypt the partition
First, we unmount the disk of interest (DOI):
```
sudo umount -R /mnt/root
```
Use cryptsetup to setup your encrypted disk. You can choose your preferred options, here I just put an example:
```
sudo cryptsetup luksFormat /dev/sdX --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --pbkdf argon2id --pbkdf-memory 1048576 --pbkdf-parallel 4 --iter-time 2000
```
where `sdX` is your partition of interest (POI).
Put your desired password, and now your disk is encrypted.
### Make it btrfs
Now, first we unencrypt the disk:
```
sudo cryptsetup luksOpen /dev/sdX cryptroot
```
where `sdX` is your POI.
And now we format it in btrfs:
```
sudo mkfs.btrfs -L "Label" /dev/mapper/cryptroot
```
### Create subvolumes
Now we mount it and create our desired subvolumes:
```
sudo mount /dev/mapper/cryptroot /mnt/root
sudo btrfs subvolume create /mnt/root/@
sudo btrfs subvolume create /mnt/root/@home
sudo btrfs subvolume create /mnt/root/@var
sudo btrfs subvolume create /mnt/root/@tmp
sudo btrfs subvolume create /mnt/root/@snapshots
```
These will look like regular subfolders, but they are not. Now, while we are mounted we can do some housekeeping: create the directories for the subvolume mounts in `@`. That means `home, var, tmp, .snapshots`.

## Step 3: Setting up our distro
### Mount subvolumes and copy the distro back
Now we will do a proper mount of our `btrfs` filesystem. First `umount` at `/mnt/root`, and then:
```
sudo mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt/root
```
The options after the `@,` can be chosen at your discretion at each mount. Now we have our root, we will mount the subvolumes where we want them.
```
sudo mount -o subvol=@home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/root/home
sudo mount -o subvol=@var,compress=zstd,noatime /dev/mapper/cryptroot /mnt/root/var
sudo mount -o subvol=@tmp,compress=zstd,noatime /dev/mapper/cryptroot /mnt/root/tmp
sudo mount -o subvol=@snapshots,compress=zstd,noatime /dev/mapper/cryptroot /mnt/root/.snapshots
```
Now, after mounting, we copy (`rsync`) the contents of the backup in `/mnt/disk` back into `/mnt/root`. If the mounts are properly done, the contents should fall into place. If you mounted `/boot` and `/boot/efi` when you copied the file tree earlier, you should mount them before doing the copy too to avoid a mismount(this was an unnecessary copy since those partitions are untouched in this case).

### Mounting setup
First, find the encrypted disk's UUID:
```
sudo blkid -s UUID -o value /dev/sdX
```
where `sdX` is your POI.
Now we need the system to recognize and mount your encrypted disk. To do so, create the file `/mnt/root/etc/crypttab` filling the `X` with the UUID:
```
echo "cryptroot UUID=X none luks,discard" | sudo tee /mnt/root/etc/crypttab
```
Then we setup the `/etc/fstab` according to our subvolumes. You will find, in the Ubuntu case, that the `/boot` and `/boot/efi` partitions are already filled out. Check them just in case, and add the subvolume mounting options like the following:
```
/dev/mapper/cryptroot / btrfs defaults,subvol=@,compress=zstd,noatime 0 1
/dev/mapper/cryptroot /home btrfs defaults,subvol=@home,compress=zstd,noatime 0 2
/dev/mapper/cryptroot /var btrfs defaults,subvol=@var,compress=zstd,noatime 0 2
/dev/mapper/cryptroot /tmp btrfs defaults,subvol=@tmp,compress=zstd,noatime 0 2
/dev/mapper/cryptroot /.snapshots btrfs defaults,subvol=@snapshots,compress=zstd,noatime 0 2
```
## Step 4: Setting up booting
Now comes the critical part. Doing this part wrongly or entering this step wrongly will probably mean you need to repeat some of the steps above.
### Mount bind and chroot
