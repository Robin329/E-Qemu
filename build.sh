#!/bin/bash -e
set -x
source env.sh

SUPPORTED_ARCH=("arm64" "arm32" "x86_64" "riscv")

if [ -z "$ARCH" ]; then
  echo "Error: No architecture specified."
  echo "Usage: $0 <architecture>"
  echo "Supported architectures: ${SUPPORTED_ARCH[*]}"
  exit 1
fi

if [[ " ${SUPPORTED_ARCH[@]} " =~ " ${ARCH} " ]]; then
  case "$ARCH" in
    arm64)
      echo "You selected ARM 64-bit architecture."
      cd $SRC
      if [ ! -d "linux" ]; then
        git clone https://mirrors.tuna.tsinghua.edu.cn/git/linux.git --depth=1
      fi
      if [ ! -d "qemu" ]; then
        git clone https://mirrors.tuna.tsinghua.edu.cn/git/qemu.git --depth=1
      fi
      cd $TDIR
      ./scripts/tools/build_kernel.sh
      ./scripts/tools/build_qemu.sh
      ;;
    arm32)
      echo "You selected ARM 32-bit architecture."
      ;;
    x86_64)
      echo "You selected x86 64-bit architecture."
      ;;
    riscv)
      echo "You selected RISC-V architecture."
      ;;
  esac
else
  echo "Error: Unsupported architecture '$ARCH'."
  echo "Supported architectures: ${SUPPORTED_ARCH[*]}"
  exit 1
fi
