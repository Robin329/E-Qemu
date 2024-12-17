#!/bin/bash -e

KERNEL_SRC=$SRC/linux

cd $KERNEL_SRC

make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 defconfig O=build -j32
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 O=build -j32
