#!/bin/bash -e

QEMU_SRC=$SRC/qemu

cd $QEMU_SRC

mkdir build
cd build
meson setup \
  --prefix=/usr/local \
  --enable-kvm \
  --target-list=aarch64-softmmu,x86_64-softmmu \
  ..

ninja -C build
