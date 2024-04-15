#!/bin/bash
board=riscv64_virt
cpus=1
image_path=${WORKDIR}/images
ip link show dev br0 >/dev/null 2>&1 || {
    sudo modprobe tun tap &&
    sudo ip link add br0 type bridge &&
    sudo ip address add 192.168.137.1/24 dev br0 &&
    sudo ip link set dev br0 up
}

sudo qemu-system-riscv64 \
    -name PolyOS-1 \
    -machine virt \
    -dtb ${WORKDIR}/qemu-virt-new.dtb \
    -m 9G \
    -smp ${cpus} \
    -no-reboot \
    -netdev bridge,id=net0,br=br0 \
    -device virtio-net-device,netdev=net0,mac=12:22:33:44:55:66 \
    -drive if=none,file=${image_path}/updater.img,format=raw,id=updater,index=5 \
    -device virtio-blk-device,drive=updater \
    -drive if=none,file=${image_path}/system.img,format=raw,id=system,index=4 \
    -device virtio-blk-device,drive=system \
    -drive if=none,file=${image_path}/vendor.img,format=raw,id=vendor,index=3 \
    -device virtio-blk-device,drive=vendor \
    -drive if=none,file=${image_path}/userdata.img,format=raw,id=userdata,index=2 \
    -device virtio-blk-device,drive=userdata \
    -drive if=none,file=${image_path}/sys_prod.img,format=raw,id=sys-prod,index=1 \
    -device virtio-blk-device,drive=sys-prod \
    -drive if=none,file=${image_path}/chip_prod.img,format=raw,id=chip-prod,index=0 \
    -device virtio-blk-device,drive=chip-prod \
    -append "loglevel=7 ip=192.168.137.3:192.168.137.1:192.168.137.1:255.255.255.0::eth0:off sn=0023456789 console=tty0,115200 console=ttyS0,115200 init=/bin/init ohos.boot.hardware=virt root=/dev/ram0 rw ohos.required_mount.system=/dev/block/vdb@/usr@ext4@ro,barrier=1@wait,required ohos.required_mount.vendor=/dev/block/vdc@/vendor@ext4@ro,barrier=1@wait,required ohos.required_mount.sys_prod=/dev/block/vde@/sys_prod@ext4@ro,barrier=1@wait,required ohos.required_mount.chip_prod=/dev/block/vdf@/chip_prod@ext4@ro,barrier=1@wait,required ohos.required_mount.data=/dev/block/vdd@/data@ext4@nosuid,nodev,noatime,barrier=1,data=ordered,noauto_da_alloc@wait,reservedsize=1073741824 ohos.required_mount.misc=/dev/block/vda@/misc@none@none=@wait,required" \
    -kernel ${image_path}/Image \
    -initrd ${image_path}/ramdisk.img \
    -nographic \
    -vga none \
    -vnc :22 \
    -device es1370 \
    -device virtio-gpu-pci,xres=486,yres=864,max_outputs=1,addr=08.0 \
    -monitor telnet:127.0.0.1:55556,server,nowait \
    -device virtio-mouse-pci \
    -device virtio-keyboard-pci \
    -device loader,file=tee-pager_v2.bin,addr=0xF0C00000 \
    -k en-us \
    -bios ./fw_dynamic.elf \
    # -S -s
    # -display sdl,gl=off

# exit
