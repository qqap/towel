# probably can just use the dir directly and the kernel build will convert to cpio
./usr/gen_initramfs.sh spec -o init.cpio
make -j 18 && cp arch/x86/boot/bzImage ~/


qemu-system-x86_64 -kernel bzImage -nographic -append "console=ttyS0" -m 256M -netdev user,id=n0,hostfwd=tcp::10022-:22 -device e1000,netdev=n0
ssh -vvv root@localhost -p 10022           