#!/bin/bash -e

export TDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SRC=$TDIR/src
export SRT_DIR=$TDIR/scripts
export SLT_DIR=$SRT_DIR/tools
export SLT_BIN_DIR=$SLT_DIR/bin

export TOOLCHAIN_DIR=$TDIR/toolchain

export ARCH=arm64

export PATH=$SRT_DIR:$SLT_BIN_DIR:$PATH

toolchain=$ARCH

# echo $toolchan
tccheck(){
    if [ ! -d "$TOOLCHAIN_DIR/$1" ];then
        echo "ERROR: not found toolchain $1 in '$TOOLCHAIN_DIR'."
        exit -1
    fi
}
case $toolchain in
	"arm32")
        tccheck gcc-arm-none-eabi-10.3-2021.10
		export PATH=$TOOLCHAIN_DIR/gcc-arm-none-eabi-10.3-2021.10/bin:$PATH
		export ARCH=armv7m
		export CROSS_COMPILE=arm-none-eabi-
	;;
    "arm64")
        tccheck gcc-arm-10.3-2021.07-aarch64-aarch64-none-elf
        export PATH=$TOOLCHAIN_DIR/gcc-arm-10.3-2021.07-aarch64-aarch64-none-elf/bin:$PATH
        export CROSS_COMPILE=aarch64-none-elf-
        export ARCH=arm64
    ;;
    "x86_64")
        tccheck gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf
        tccheck gcc-arm-10.3-2021.07-aarch64-aarch64-none-elf
        export PATH=$TOOLCHAIN_DIR/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin:$TOOLCHAIN_DIR/gcc-arm-10.3-2021.07-aarch64-aarch64-none-elf/bin:$PATH
        export AARCH32_CROSS_COMPILE=arm-none-linux-gnueabihf-
        export AARCH64_CROSS_COMPILE=aarch64-none-elf-
    ;;
	*)
		echo "$toolchain error. Should be 'arm32', 'r52', 'optee' and 'gnu64'."
        exit -1
	;;
esac
