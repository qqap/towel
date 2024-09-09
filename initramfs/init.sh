#!/bin/sh

mount -t sysfs sysfs /sys
mount -t proc proc /proc
mount -t devtmpfs udev /dev

# some log level thing?
echo "2 4 1 7" > /proc/sys/kernel/printk

for cmd in $(busybox --list); do
    busybox ln -s /bin/busybox /bin/$cmd
done

# The devpts (Device PTS) filesystem is essential for providing a pseudo-TTY interface for SSH connections.
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts

# busybox ip link set eth0 up
# busybox ip addr add 66.78.40.119/24 dev eth0
# busybox ip route add default via 66.78.40.1
# busybox ping -c 4 8.8.8.8

# Qemu local
busybox ip link set eth0 up
busybox ip addr add 10.0.2.15/24 dev eth0
busybox ip route add default via 10.0.2.2
busybox ping -c 4 8.8.8.8

echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Create the .ssh directory with correct permissions
mkdir -p /root/.ssh
chmod 700 /root/.ssh

echo "root:x:0:0:root:/root:/bin/sh" > /etc/passwd

# Add the SSH public key to authorized_keys file
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC4DhuwpxW2YuZBrEWuIFY0nrZsVIW4Kma7HMxeGL1F64fnK68plpRcojd0scjwXol7BC7Pv0PWTIvnDKWMrbSuVoOXjf5/s79UQ0RGT7zPOYg2onx1JytqSHnEM7x7/uPok9edZ0HwK16MZaH/p3EOpBzsB1hcIiFdAkKew7rmjy0a65hZpoi2ikciWYD8R40n7G1NuDgJBgwzCOShXSg3EqPN6R8dQ4olhJgQoZJnwpP7ZUJfrwdyJGa4aSc54tSWNMpWxlurEZiL/twCO2io0X8wjQ12tRHby4xP6Ejcnx9RLABrZdxFzHpow4ZhNI5aIxtv7PAi3W4WMOhzb9s6XNopBkkW851D5FIELiKSin3LY/6qts4LSbVretxek5L09FI9a6DkutAs9vjIJHkRUnr4exy7opjF3YprpgnlFPyvj9pznaKHvwtEuNxXX5qyoi6F3d6Zhc57XGcYXJbwHNelX6jNWJVBpmdPVZTwNr85BrZOR3gbcVTByDFa9kE= humour@MacBook-Pro.local" > /root/.ssh/authorized_keys

# Set correct permissions for the authorized_keys file
chmod 600 /root/.ssh/authorized_keys

mkdir /etc/dropbear && dropbearmulti dropbear -s -R

/bin/sh
