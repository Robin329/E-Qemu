#!/bin/bash -e

QEMU_SRC=$SRC/qemu

cd $QEMU_SRC

mkdir build
cd build
../configure \
  --target-list=aarch64-softmmu,x86_64-softmmu,aarch64-linux-user,riscv64-softmmu,arm-softmmu

ninja
