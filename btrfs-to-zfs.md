# BTRFS filesystem with ZFS backup

In this tutorial I will explain how to keep a `btrfs` root filesystem while using zfs for its archival storage as a filesystem for backups.

## Mount your zpool
```
zpool import backup
```

```
sudo zfs load-key backup/secure
sudo zfs mount backup/secure
```

## BTRFS streams

`btrfs` streams created by `send` cannot be understood by zfs, so we will use rsync. To better have everything on its place, we will also do `btrfs snapshots`.

```
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
sudo btrfs subvolume snapshot -r / /.snapshots/@_backup_$TIMESTAMP
sudo btrfs subvolume snapshot -r /var /.snapshots/@var_backup_$TIMESTAMP
sudo btrfs subvolume snapshot -r /home /.snapshots/@home_backup_$TIMESTAMP
```

## Using rsync

To avoid heavy files we are not interested in, we will keep a `rsync_excludes.txt` that contains the filepaths to avoid, for example, when doing a backup of root, `proc/`, `run/` and so on.

To do the backup, we will:
```
sudo rsync -avxHAXS --numeric-ids --acls --xattrs --hard-links --sparse --progress --exclude-from=rsync_excludes.txt /.snapshots/@subvol_backup_$TIMESTAMP/ /mnt/secure/var/
```
## ZFS snapshots

To ensure that on deletion we do not lose past files that we deleted and might want, we also keep zfs snapshots.

```
sudo zfs snapshot backup/secure/root@first
sudo zfs snapshot backup/secure/home@first
sudo zfs snapshot backup/secure/var@first
```
## Intermediate
```
zpool list
rsync --delete
```
## Finalize

```
sudo zfs unmount -a

sudo zfs unload-key backup/secure

sudo zpool export backup
```
