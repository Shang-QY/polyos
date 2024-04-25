#!/bin/bash

if [ -z "$WORKDIR" ]; then
    echo "ERROR: WORKDIR environment variable is not set. Please set it to the correct directory and try again."
    exit 1
fi

if [ ! -d "$WORKDIR/test_polyos_with_optee" ]; then
    echo "ERROR: The directory $WORKDIR/test_polyos_with_optee does not exist. Please check the WORKDIR setting."
    exit 1
fi

# Prepare toolchain
echo Preparing toolchain
cd "$WORKDIR/test_polyos_with_optee"
mkdir -p toolchain && cd toolchain/
if [ ! -f "riscv64-glibc-ubuntu-20.04-gcc-nightly-2023.07.07-nightly.tar.gz" ]; then
    wget https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2023.07.07/riscv64-glibc-ubuntu-20.04-gcc-nightly-2023.07.07-nightly.tar.gz
    tar zxvf riscv64-glibc-ubuntu-20.04-gcc-nightly-2023.07.07-nightly.tar.gz
fi
export TOOLCHAIN=$WORKDIR/test_polyos_with_optee/toolchain

# Compile OPTEE OS
echo Compiling OPTEE OS
cd "$WORKDIR/test_polyos_with_optee"
if [ ! -d "optee_os" ]; then
    git clone https://github.com/Shang-QY/optee_os.git -b dev-rpxy-optee-v3
fi

cd optee_os
make CFG_TEE_CORE_LOG_LEVEL=3 CROSS_COMPILE64="$TOOLCHAIN/riscv/bin/riscv64-unknown-linux-gnu-" \
    ARCH=riscv CFG_DT=n CFG_RPMB_FS=y CFG_RPMB_WRITE_KEY=y \
    CFG_RV64_core=y CFG_TDDRAM_START=0xF0C00000 CFG_TDDRAM_SIZE=0x800000 CFG_SHMEM_START=0xF1600000 \
    CFG_SHMEM_SIZE=0x200000 PLATFORM=virt ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d
cp out/riscv-plat-virt/core/tee.bin "$WORKDIR/tee-pager_v2.bin"

# Compile OPTEE Client
echo Compiling OPTEE Client
cd "$WORKDIR/test_polyos_with_optee"
if [ ! -d "optee_client" ]; then
    git clone https://github.com/OP-TEE/optee_client
fi

cd optee_client
if [ ! -d "build" ]; then
    mkdir -p build
fi
cd build
rm -rf *
cmake CFG_TEE_CLIENT_LOG_LEVEL=3 CFG_TEE_SUPP_LOG_LEVEL=3 \
    -DCMAKE_C_COMPILER="$TOOLCHAIN/riscv/bin/riscv64-unknown-linux-gnu-gcc" \
    -DCMAKE_INSTALL_PREFIX=./out/export/usr ..
make && make install

# Compile OPTEE Examples
echo Compiling OPTEE Examples
cd "$WORKDIR/test_polyos_with_optee"
if [ ! -d "optee_examples" ]; then
    git clone https://github.com/linaro-swg/optee_examples.git
fi

cd optee_examples/hello_world/host
make CROSS_COMPILE="$TOOLCHAIN/riscv/bin/riscv64-unknown-linux-gnu-" \
    TEEC_EXPORT="$WORKDIR/test_polyos_with_optee/optee_client/build/out/export/usr" --no-builtin-variables

cd -
cd optee_examples/hello_world/ta
make CROSS_COMPILE="$TOOLCHAIN/riscv/bin/riscv64-unknown-linux-gnu-" PLATFORM=vexpress-qemu_virt \
    TA_DEV_KIT_DIR="$WORKDIR/test_polyos_with_optee/optee_os/out/riscv-plat-virt/export-ta_rv64"
cd -
