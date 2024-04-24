#!/bin/bash

if [ -z "$WORKDIR" ]; then
    echo "ERROR: WORKDIR environment variable is not set. Please set it to the correct directory and try again."
    exit 1
fi

if [ ! -d "$WORKDIR/test_polyos_with_optee" ]; then
    echo "ERROR: The directory $WORKDIR/test_polyos_with_optee does not exist. Please check the WORKDIR setting."
    exit 1
fi

export TOOLCHAIN=$WORKDIR/test_polyos_with_optee/toolchain
if [ ! -d "$TOOLCHAIN" ]; then
    echo "ERROR: The directory $TOOLCHAIN does not exist. Please check the toolchain compilation."
    exit 1
fi

if [ ! -d "$WORKDIR/test_polyos_with_optee/optee_client/build" ]; then
    echo "ERROR: The directory $WORKDIR/test_polyos_with_optee/optee_client/build does not exist. Please check the optee_client compilation."
    exit 1
fi

if [ ! -d "$WORKDIR/test_polyos_with_optee/optee_os/out" ]; then
    echo "ERROR: The directory $WORKDIR/test_polyos_with_optee/optee_os/out does not exist. Please check the optee_os compilation."
    exit 1
fi

if [ ! -f "$WORKDIR/images/system.img" ]; then
    echo "ERROR: The file $WORKDIR/images/system.img does not exist. Please check the image preparation."
    exit 1
fi

# Compile OPTEE Example
echo Compiling OPTEE Example -- $1
cd "$WORKDIR/test_polyos_with_optee"
if [ ! -d "optee_examples" ]; then
    git clone https://github.com/linaro-swg/optee_examples.git
fi

cd optee_examples/$1/host
make CROSS_COMPILE="$TOOLCHAIN/riscv/bin/riscv64-unknown-linux-gnu-" \
    TEEC_EXPORT="$WORKDIR/test_polyos_with_optee/optee_client/build/out/export/usr" --no-builtin-variables

cd -
cd optee_examples/$1/ta
make CROSS_COMPILE="$TOOLCHAIN/riscv/bin/riscv64-unknown-linux-gnu-" PLATFORM=vexpress-qemu_virt \
    TA_DEV_KIT_DIR="$WORKDIR/test_polyos_with_optee/optee_os/out/riscv-plat-virt/export-ta_rv64"
cd -

# Install OPTEE Example
echo Installing OPTEE Example -- $1
cd $WORKDIR
mkdir -p mnt
sudo mount images/system.img ./mnt

sudo cp test_polyos_with_optee/optee_examples/$1/ta/*.ta ./mnt/system/lib/optee_armtz/
sudo cp test_polyos_with_optee/optee_examples/$1/host/optee_example_$1 ./mnt/system/bin/

sudo umount ./mnt
