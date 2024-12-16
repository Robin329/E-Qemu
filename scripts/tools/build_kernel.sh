#!/bin/bash -e

KERNEL_SRC=$SRC/linux

cd $KERNEL_SRC
make ARCH=$ARCH defconfig
make -j12
