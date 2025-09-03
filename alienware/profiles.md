# Changing performance profiles
## Enabling alienware-wmi profiles
Make sure the driver is installed, as this depends on that driver:
```
lsmod | grep alienware-wmi
```
If installed, add the following line to the file `/etc/modprobe.d/alienware-wmi.conf`:
```
options alienware-wmi force_platform_profile=1
```
And restart the driver:
```
sudo modprobe -r alienware-wmi
sudo modprobe alienware-wmi
```
Now check that it was successful:
```
grep -l "alienware-wmi" /sys/class/platform-profile/platform-profile-*/name
```
## Scripts
Now the toggle is mainly in the `profile` file of the `/sys/class/platform-profile/platform-profile-*/` folder that popped up in the previous command. Your options are shown in the `choices` file of the same folder. I have not found any way to manage, use or control fan dynamic curve speeds or individual fan boost values. 

I have included in this folder two bash scripts that switch between the `performance` and the `balanced-performance` profiles. You can edit them to include the proper profile folder and make them executable to use them. Those are the ones I find most useful.

## Personalization
You can check what profiles you can use (and create your own scripts), by doing:
```[bash]
cat /sys/class/platform-profile/platform-profile-*/choices
```
You may find more useful options that I did.