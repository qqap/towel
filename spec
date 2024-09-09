# This section defines the device nodes and the /dev directory in the initramfs.
# The 'dir' command creates the /dev directory with permissions set to 755,
# allowing the owner (0) to read, write, and execute, while the group (0) and others can read and execute.
# The 'nod' command creates special files (device nodes) within the /dev directory.
# The first 'nod' creates a character device for the console with permissions 644,
# allowing the owner (0) to read and write, while the group (0) and others can only read.
# The second 'nod' creates a block device for loop0 with permissions 644, similar to the console.
# Major and minor numbers are used to identify devices; the major number identifies the driver associated with the device,
# while the minor number is used to identify a specific device or partition managed by that driver.
dir /dev 755 0 0
nod /dev/console 644 0 0 c 5 1  # c: character device, 5: major number for console, 1: minor number for console
nod /dev/loop0 644 0 0 b 7 0     # b: block device, 7: major number for loop devices, 0: minor number for loop0

# 1000 1000: These are the UID (User ID) and GID (Group ID). 
# They represent the user and group that own the directory. 
# “1000” typically corresponds to the first non-root user created on the system. 
# It’s like saying “This part of the ship belongs to crew member 1000 and their group.”
dir /bin 755 1000 1000

slink /bin/sh busybox 777 0 0
slink /bin/mount busybox 777 0 0

file /bin/busybox initramfs/busybox 755 0 0
file /bin/dropbearmulti initramfs/dropbearmulti 755 0 0
file /bin/zsh initramfs/zsh 755 0 0
file /bin/git initramfs/git 755 0 0
file /init initramfs/init.sh 755 0 0

dir /proc 755 0 0
dir /sys 755 0 0
dir /mnt 755 0 0
dir /etc 755 0 0