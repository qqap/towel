#!/bin/bash -e
# Tiny Linux Bootloader
# (c) 2014- Dr Gareth Owen (www.ghowen.me). All rights reserved.

# License information...
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Define input and output files
INPUT="bsect.asm"        # Assembly source file for the bootloader
OUTPUT="disk.img"            # Final output file containing bootloader, kernel, and initrd
# KERN="./barebones"       # Kernel binary file
# KERN="./barebones"       # Kernel binary file

KERN="./bzImage"       # Kernel binary file
# KERN="./bzImage-5.17.3"       # Kernel binary file

# RD="./init.cpio"          # Initial RAM disk (initrd) file
# RD="./a"          # Initial RAM disk (initrd) file

# Calculate sizes of kernel and ramdisk
K_SZ=`stat -c %s $KERN`  # Get size of kernel file in bytes
# R_SZ=`stat -c %s $RD`    # Get size of initrd file in bytes

# Calculate padding needed to align to 512-byte sectors
K_PAD=$((512 - $K_SZ % 512))  # Padding for kernel
# R_PAD=$((512 - $R_SZ % 512))  # Padding for initrd

echo "Kernel size: $K_SZ bytes"
# echo "Initrd size: $R_SZ bytes"
echo "Kernel padding: $K_PAD bytes"
# echo "Initrd padding: $R_PAD bytes"

# Assemble the bootloader with the initrd size defined
nasm -o $OUTPUT -D initRdSizeDef=0 $INPUT

# Append kernel to the bootloader
cat $KERN >> $OUTPUT

# Add padding after kernel if necessary
if [[ $K_PAD -le 512 ]]; then
    dd if=/dev/zero bs=1 count=$K_PAD >> $OUTPUT
fi

# # Append initrd to the file
# cat $RD >> $OUTPUT

# # Add padding after initrd if necessary
# if [[ $R_PAD -lt 512 ]]; then
#     dd if=/dev/zero bs=1 count=$R_PAD >> $OUTPUT
# fi

# Calculate total size and display information
TOTAL=`stat -c %s $OUTPUT`
echo "concatenated bootloader, kernel and initrd into ::> $OUTPUT"
echo "Note, your first partition must start after sector $(($TOTAL / 512))"
echo "change the big.init, barebones laterQ!!"
