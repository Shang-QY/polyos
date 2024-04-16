# Run polyos with Penglai-Zone (OP-TEE)

## 1、Pre-Requist: Compile and run polyos (RISC-V openHarmony)

### 1. Prepare the environment

#### Install git-lfs
openHarmony includes several lagre files, which are managed by the git-lfs:
```
sudo apt install git-lfs
```

#### Install repo
Use repo to obtain the source code of PolyOS (RISC-V openHarmony)
```
sudo apt install repo
```

#### Install docker
https://docs.docker.com/engine/install/

#### Intsll QEMU
```
sudo apt install qemu-system qemu
qemu-system-riscv64 --version # 确保qemu的版本比较新

QEMU emulator version 8.2.1
Copyright (c) 2003-2023 Fabrice Bellard and the QEMU Project developers
```

### 2. Obtain the source code of OpenHarmony
```
mkdir polyos && cd polyos
export WORKDIR=`pwd`

git config --global credential.helper 'cache --timeout=3600' 

repo init -u https://isrc.iscas.ac.cn/gitlab/riscv/polyosmobile/ohos_qemu/manifest.git -b OpenHarmony-3.2-Release --no-repo-verify

repo sync -j$(nproc) -c && repo forall -c 'git lfs pull'
```

### 3. Compile the openHarmony in the Linux 
https://polyos.iscas.ac.cn/docs/developer-guides/build-polyos-mobile/on-ubuntu

#### Using the docker environment 
```
cd $WORKDIR
docker run -it --rm -v $(pwd):/polyos-mobile --workdir /polyos-mobile swr.cn-south-1.myhuaweicloud.com/openharmony-docker/openharmony-docker:1.0.0

bash build/prebuilts_download.sh # 获取编译依赖的一些预构建二进制工具

bash build.sh --product-name qemu_riscv64_virt_linux_system --ccache # 启动编译
```
It needs several time (about 3~4 hours, depends on you machine). After the compilation, the target image is under the directory: out/riscv64_virt/packages/phone/images

### 4. Run the openHarmony in the qemu

Run the following scripts：
```
#!/bin/bash 
board=riscv64_virt 
cpus=8 
memory=8096 
image_path=${WORKDIR}/out/${board}/packages/phone/images 
QEMU=$(which qemu-system-riscv64) 
ip link show dev br0 >/dev/null 2>&1 || { 
    sudo modprobe tun tap && 
    sudo ip link add br0 type bridge && 
    sudo ip address add 192.168.137.1/24 dev br0 && 
    sudo ip link set dev br0 up 
} 
sudo $QEMU \ 
    -name PolyOS-1 \ 
    -machine virt \ 
    -m ${memory} \ 
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
    -append "loglevel=1 ip=192.168.137.3:192.168.137.1:192.168.137.1:255.255.255.0::eth0:off sn=0023456789 console=tty0,115200 console=ttyS0,115200 init=/bin/init ohos.boot.hardware=virt root=/dev/ram0 rw ohos.required_mount.system=/dev/
block/vdb@/usr@ext4@ro,barrier=1@wait,required ohos.required_mount.vendor=/dev/block/vdc@/vendor@ext4@ro,barrier=1@wait,required ohos.required_mount.sys_prod=/dev/block/vde@/sys_prod@ext4@ro,barrier=1@wait,required ohos.required_mount.ch
ip_prod=/dev/block/vdf@/chip_prod@ext4@ro,barrier=1@wait,required ohos.required_mount.data=/dev/block/vdd@/data@ext4@nosuid,nodev,noatime,barrier=1,data=ordered,noauto_da_alloc@wait,reservedsize=1073741824 ohos.required_mount.misc=/dev/b
lock/vda@/misc@none@none=@wait,required" \ 
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
    -k en-us  
    #-display sdl,gl=off 

exit
```

## 2、Download Penglai-Zone project
```
cd $WORKDIR
git clone https://github.com/Shang-QY/test_polyos_with_optee.git
```

## 3、Prepare OPTEE and PenglaiZone opensbi

Download and install toolchain
```
cd /opt/
sudo wget -c https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2023.07.07/riscv64-glibc-ubuntu-20.04-gcc-nightly-2023.07.07-nightly.tar.gz
sudo tar zxvf riscv64-glibc-ubuntu-20.04-gcc-nightly-2023.07.07-nightly.tar.gz
cd -
```

Compile OpenSBI

```
cd $WORKDIR/test_polyos_with_optee
git clone https://github.com/yli147/opensbi.git -b dev-rpxy-optee-v3
cd opensbi
CROSS_COMPILE=riscv64-linux-gnu- make PLATFORM=generic
cp build/platform/generic/firmware/fw_dynamic.elf $WORKDIR
```

Compile OPTEE-OS
```
cd $WORKDIR/test_polyos_with_optee
git clone https://github.com/yli147/optee_os.git -b dev-rpxy-optee-v3
cd optee_os
make CFG_TEE_CORE_LOG_LEVEL=3 CROSS_COMPILE64=/opt/riscv/bin/riscv64-unknown-linux-gnu- ARCH=riscv CFG_DT=n CFG_RPMB_FS=y CFG_RPMB_WRITE_KEY=y CFG_RV64_core=y CFG_TDDRAM_START=0xF0C00000 CFG_TDDRAM_SIZE=0x800000 CFG_SHMEM_START=0xF1600000 CFG_SHMEM_SIZE=0x200000 PLATFORM=virt ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d
cp out/riscv-plat-virt/core/tee.bin $WORKDIR/tee-pager_v2.bin
```

Compile OPTEE-client
```
cd $WORKDIR/test_polyos_with_optee
git clone https://github.com/OP-TEE/optee_client
cd optee_client
mkdir build
cd build
cmake CFG_TEE_CLIENT_LOG_LEVEL=3 CFG_TEE_SUPP_LOG_LEVEL=3 -DCMAKE_C_COMPILER=/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr .. clean
cmake CFG_TEE_CLIENT_LOG_LEVEL=3 CFG_TEE_SUPP_LOG_LEVEL=3 -DCMAKE_C_COMPILER=/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr ..
make
make install
```

Compile OPTEE-examples
```
cd $WORKDIR/test_polyos_with_optee
git clone https://github.com/linaro-swg/optee_examples.git
cd optee_examples/hello_world/host
make \
    CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    TEEC_EXPORT=$WORKDIR/test_polyos_with_optee/optee_client/build/out/export/usr \
    --no-builtin-variables clean
make \
    CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    TEEC_EXPORT=$WORKDIR/test_polyos_with_optee/optee_client/build/out/export/usr \
    --no-builtin-variables
cd -
cd optee_examples/hello_world/ta
make \
    CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    PLATFORM=vexpress-qemu_virt \
    TA_DEV_KIT_DIR=$WORKDIR/test_polyos_with_optee/optee_os/out/riscv-plat-virt/export-ta_rv64 clean
make \
    CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    PLATFORM=vexpress-qemu_virt \
    TA_DEV_KIT_DIR=$WORKDIR/test_polyos_with_optee/optee_os/out/riscv-plat-virt/export-ta_rv64
cd -
```

Compile Rootfs (can be ignored, if you use the provided image)
```
cd $WORKDIR/test_polyos_with_optee
git clone https://github.com/buildroot/buildroot.git -b 2023.08.x
cd buildroot
make qemu_riscv64_virt_defconfig
make -j $(nproc)
mkdir -p root
tar vxf output/images/rootfs.tar -C ./root
```

## 4、Prepare Device Tree Blob

```
cd $WORKDIR
dtc -I dts -O dtb -o qemu-virt-new.dtb test_polyos_with_optee/qemu-virt-restrict.dts
```

## 5、Patch and recompile polyos linux kernel (can be ignored, if you use the provided image)

编辑 defconfig: $WORKDIR/device/board/qemu/riscv64_virt/kernel/riscv64_virt.config，在其中添加：
```
CONFIG_TEE=y
CONFIG_OPTEE=y
CONFIG_OPTEE_SHM_NUM_PRIV_PAGES=1
```

源码打补丁并编译：
```
cd $WORKDIR
cd kernel/linux/linux-5.10
git apply < $WORKDIR/linux_optee.patch
cd -

docker run -it --rm -v $(pwd):/polyos-mobile --workdir /polyos-mobile swr.cn-south-1.myhuaweicloud.com/openharmony-docker/openharmony-docker:1.0.0

./build.sh --product-name qemu_riscv64_virt_linux_system --build-target build_kernel --gn-args linux_kernel_version=\"linux-5.10\" # in docker
```

## 6、Copy CA/TA to polyos filesystem
```
cd $WORKDIR

# Copy optee executable & lib

mkdir -p mnt
sudo mount images/system.img ./mnt

# Can be ignored, if you use the provide image
sudo cp -rf test_polyos_with_optee/buildroot/root/lib/* mnt/system/lib64/

sudo cp -rf test_polyos_with_optee/optee_client/build/out/export/usr/sbin/tee-supplicant ./mnt/system/bin/

sudo mkdir -p ./mnt/system/lib/optee_armtz
sudo cp test_polyos_with_optee/optee_examples/hello_world/ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta ./mnt/system/lib/optee_armtz/
sudo cp test_polyos_with_optee/optee_examples/hello_world/host/optee_example_hello_world ./mnt/system/bin/

sudo umount ./mnt


# Copy the script to enable the tee-supplicant:

sudo mount -o loop images/userdata.img ./mnt

cat > mnt/start_optee_supplicant.sh << EOF
if [ -e /bin/tee-supplicant -a -e /dev/teepriv0 ]; then
        echo "Starting tee-supplicant..."
        tee-supplicant&
        ifconfig lo up
        exit 0
else
        echo "tee-supplicant or TEE device not found"
        exit 1
fi
;;
EOF

sudo chmod a+x mnt/start_optee_supplicant.sh

sudo umount ./mnt
```

## 7、Run polyos with optee

```
cd $WORKDIR
./test_polyos_with_optee/run_polyos.sh
```

After Login, execute 
```
cd data
./start_optee_supplicant.sh
optee_example_hello_world
```


# 附录（for qingyu only
```
sudo cp -rf ../enable_optee/optee_client/build/out/export/usr/sbin/tee-supplicant ./mnt/system/bin/

sudo mkdir -p ./mnt/system/lib/optee_armtz
sudo cp ../enable_optee/optee_examples/hello_world/ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta ./mnt/system/lib/optee_armtz/
sudo cp ../enable_optee/optee_examples/hello_world/host/optee_example_hello_world ./mnt/system/bin/
```