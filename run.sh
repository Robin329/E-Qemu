#!/bin/bash

source env.sh

## boot from pflash, for the image offset, see tools/uboot/images.sh
function _size16b() {
	size=$1
	echo -n 0x$(echo "obase=16;$size" | bc)
}
function _size16b_m() {
	size=$1
	echo $(_size16b $((size * 1024 * 1024)))
}

HOST_NAME=`ls /home/`
ROOT=$TDIR
QEMUT=qemu-system-aarch64
BUSYBOX=$SRC/busybox
OUTPUT=$ROOT/build
ROOTFS_NAME=ext4
CROSS_COMPILE=aarch64-linux-gnu
FS_TYPE=ext4
FS_TYPE_TOOLS=mkfs.ext4
ROOTFS_SIZE=150
FREEZE_SIZE=512
DL=$ROOT
DEBIAN_PACKAGE=buster-base-arm64.tar.gz.N.bsp
RAM_SIZE=2048
LINUX_DIR=${SRC}/linux/build/arch
HOSTSHARE=${SRC}/hostshare
NET_CFG=${ROOT}/package/networking
ROUTE=$(ifconfig | awk '{print $2}' | sed -n '2p')
CMDLINE="earlycon root=/dev/vda rw rootfstype=${FS_TYPE} console=ttyAMA0 init=/sbin/init loglevel=8 route=192.168.11.103 iface=eth0 rw fsck.repair=yes  rootwait sharetag=hostshare sharedir=/hostshare"

#------------------------------------------------------
U_ROOT_IMAGE=/home/ubuntu/workspace/BiscuitOS/output/linux-newest-arm64/buildroot-master/output/images
ROOT_IMAGE=${U_ROOT_IMAGE}
# DTB_IMAGE=${LINUX_DIR}/${ARCH}/boot/dts/qemu/virt-a710.dtb
DTB_IMAGE=${LINUX_DIR}/${ARCH}/boot/dts/qemu/qemu_a72_4core.dtb
KERNEL_IMAGE=${LINUX_DIR}/${ARCH}/boot/Image
IMAGES_DIR=${ROOT}
PFLASH_IMG=${ROOT}/pflash.img
SD_IMG=${ROOT}/sd.img
ENV_IMG=${ROOT}/env.img
# Get DRAM start & size via `bdinfo`
KRN_ADDR="0x45000000"
KRN_SIZE=20
# ramdisk_addr_r=0x44000000
RDK_ADDR="-"
RDK_SIZE=6
DTB_ADDR="0x44000000"
DTB_SIZE=2
PFLASH_SIZE=64
BOOTDEV=flash
# Boot images from pflash
##
## cp 0x40000000 0x60003000 0x500000;
## cp 0x40500000 0x60900000 0x400000;
## cp 0x40900000 0x60500000 0x100000;
##
# get FLASH info from `flinfo`: 64M pflash0@0x00000000, 64M pflash1@0x04000000
# The first one is used for -bios, the second one for environment, dtb and ramdisk if required
PFLASH_BASE="0x4000000"
PFLASH_SIZE=64
PFLASH_BS=512
# Environment Offset, see CONFIG_ENV_OFFSET in $UCONFIG
# ENV_DEV=flash
ENV_OFFSET=0
ENV_SIZE=2
ENV_DEV=pflash
if [ "${ENV_DEV}" = "flash" ]; then
	ENV_ADDR=0x4000000
else
	ENV_ADDR=0x49000000
fi
####
# config.sh
####
_UBOOT_DIR=$SRC/u-boot
_CONFIG_FILE=qemu-arm.h
CONFIG_FILE=$_UBOOT_DIR/include/configs/$_CONFIG_FILE
KERNEL_IMG=uImage
RAMDISK_IMG=ramdisk
DTB_IMG=dtb

# By default, boot from tftp
U_BOOT_CMD=bootcmd1
if [ "${BOOTDEV}" = "sdcard" ]; then
	U_BOOT_CMD=bootcmd2
fi
echo "BOOTDEV:${BOOTDEV}"
if [ "${BOOTDEV}" = "flash" ]; then
	echo -e "Use bootcmd3"
	U_BOOT_CMD=bootcmd3
fi
if [ "${BOOTDEV}" = "ram" ]; then
	U_BOOT_CMD=bootcmd4
	RAM_BOOT=1
fi

# Core configuration

## boot from tftp
TFTP_KERNEL="tftpboot $KRN_ADDR $KERNEL_IMG;"
[ "$RDK_ADDR" != "-" ] && TFTP_RAMDISK="tftpboot $RDK_ADDR $RAMDISK_IMG;"
[ "$DTB_ADDR" != "-" ] && TFTP_DTB="tftpboot $DTB_ADDR $DTB_IMG;"

IP=192.168.64.5
# Get delayed ip, route and cmdline
echo $IP | grep -q ifconfig
[ $? -eq 0 ] && eval "IP=\"$IP\""
echo $ROUTE | grep -q ifconfig
[ $? -eq 0 ] && eval "ROUTE=\"$ROUTE\""
echo $CMDLINE | grep -q ifconfig
[ $? -eq 0 ] && eval "CMDLINE=\"$CMDLINE\""

# echo -----------------------------
#
# echo $IP
# echo $ROUTE
# echo $CMDLINE
#
# echo -----------------------------

IPADDR="setenv ipaddr $IP;"
SERVERIP="setenv serverip $ROUTE;"
BOOTARGS="setenv bootargs '"$(echo -n "$CMDLINE" | sed 's%"%\\\\"%g' | sed "s%'%\\\\\"%g")"';"
TFTPS="$TFTP_KERNEL $TFTP_RAMDISK $TFTP_DTB"
[ "$DTB_ADDR" == "-" ] && DTB_ADDR=""
BOOTM="$BOOTX $KRN_ADDR $RDK_ADDR $DTB_ADDR"

BOOT_TFTP="$IPADDR $SERVERIP $BOOTARGS $TFTPS $BOOTM"

# Get the real address if not specified
[ -z "$ENV_ADDR" ] && ENV_ADDR=$(_size16b $(($PFLASH_BASE + $ENV_OFFSET)))

[ -z "$ENV_SIZE" ] && ENV_SIZE=0
_ENV_SIZE=$(_size16b_m $ENV_SIZE)
_KRN_SIZE=$(_size16b_m $KRN_SIZE)
_RDK_SIZE=$(_size16b_m $RDK_SIZE)
_DTB_SIZE=$(_size16b_m $DTB_SIZE)

echo "_ENV_SIZE:${_ENV_SIZE} ADDR:$ENV_ADDR"
echo "_KRN_SIZE:${_KRN_SIZE} ADDR:$KRN_ADDR"
echo "_RDK_SIZE:${_RDK_SIZE} ADDR:$RDK_ADDR"
echo "_DTB_SIZE:${_DTB_SIZE} ADDR:$DTB_ADDR"

KERNEL_BASE=$(_size16b $(($PFLASH_BASE + $_ENV_SIZE)))
RAMDISK_BASE=$(_size16b $(($PFLASH_BASE + $_ENV_SIZE + $_KRN_SIZE)))
DTB_BASE=$(_size16b $(($PFLASH_BASE + $_ENV_SIZE + $_KRN_SIZE + $_RDK_SIZE)))

BOOTARGS="setenv bootargs '${CMDLINE}';"

BOOTX=booti
[ "$DTB_ADDR" == "-" ] && DTB_ADDR=""
BOOTM="$BOOTX $KRN_ADDR $RDK_ADDR $DTB_ADDR"

echo "KERNEL_BASE ADDR BASE:$KERNEL_BASE"
echo "RAMDISK_BASE ADDR BASE:$RAMDISK_BASE"
echo "DTB_BASE ADDR BASE:$DTB_BASE"

PFLOAD_KERNEL="cp.b $KERNEL_BASE $KRN_ADDR $_KRN_SIZE;"
[ "$RDK_ADDR" != "-" ] && PFLOAD_RAMDISK="cp $RAMDISK_BASE $RDK_ADDR $_RDK_SIZE;"
[ "$DTB_ADDR" != "-" ] && PFLOAD_DTB="cp $DTB_BASE $DTB_ADDR $_DTB_SIZE;"
PFLOADS="$PFLOAD_KERNEL $PFLOAD_RAMDISK $PFLOAD_DTB"
BOOT_PFLASH="$BOOTARGS $PFLOADS  $BOOTM"

## boot from sdcard/mmc
FATLOAD_KERNEL="fatload mmc 0:0 $KRN_ADDR $KERNEL_IMG;"
[ "$RDK_ADDR" != "-" ] && FATLOAD_RAMDISK="fatload mmc 0:0 $RDK_ADDR $RAMDISK_IMG;"
[ "$DTB_ADDR" != "-" ] && FATLOAD_DTB="fatload mmc 0:0 $DTB_ADDR $DTB_IMG;"
FATLOADS="$FATLOAD_KERNEL $FATLOAD_RAMDISK $FATLOAD_DTB"

BOOT_SDCARD="$BOOTARGS $FATLOADS $BOOTM"

BOOT_PFLASH="$BOOTARGS $PFLOADS $BOOTM"

BOOT_RAM="$BOOTARGS $BOOTM"

## Use tftp by default
BOOT_CMD=$U_BOOT_CMD

# build env image or customize config file?

## build env image
# if [ -z "$_CONFIG_FILE" ]; then

case $BOOT_CMD in
bootcmd4)
	boot_cmd=$BOOT_RAM
	;;
bootcmd3)
	boot_cmd=$BOOT_PFLASH
	;;
bootcmd2)
	boot_cmd=$BOOT_SDCARD
	;;
*)
	boot_cmd=$BOOT_TFTP
	;;
esac
truncate -s 1M $ENV_IMG
echo -e -n "bootcmdx=${boot_cmd}\0" >$ENV_IMG
hexdump -C $ENV_IMG
# exit 0
# fi
## customize config file

# Others
CONFIG_SYS_CBSIZE=1024
CONFIG_INITRD_TAG=1
CONFIG_OF_LIBFDT=1
# aligh with 1M for env partition, for saveenv command
FLASH_MAX_SECTOR_SIZE=0x00100000
CONFIG_EXTRA_ENV_SETTINGS="\"bootcmd1=$BOOT_TFTP\\\\0bootcmd2=$BOOT_SDCARD\\\\0bootcmd3=$BOOT_PFLASH\\\\0bootcmd4=$BOOT_RAM\\\\0bootcmdx=run $BOOT_CMD\\\\0\""

# Convert from M to bytes
ENV_OFFSET=$(_size16b_m $ENV_OFFSET)
# Get the real address if not specified
[ -z "$ENV_ADDR" ] && ENV_ADDR=$(_size16b $((PFLASH_BASE + ENV_OFFSET)))
echo "ENV_OFFSET:$ENV_OFFSET"
# Get the real address if not specified
CONFIG_BOOTCOMMAND="\"env import $ENV_ADDR $CONFIG_SYS_CBSIZE; run bootcmdx\""
# The header for SZ_16M is not always there, use magic number directly
CONFIG_SYS_BOOTM_LEN=0x01000000

# More
EXTRA_CONFIGS=$(env | grep ^CONFIG | cut -d'=' -f1)

echo $CONFIG_BOOTCOMMAND

# Build the config lines

CONFIGS="CONFIG_EXTRA_ENV_SETTINGS FLASH_MAX_SECTOR_SIZE CONFIG_BOOTCOMMAND CONFIG_SYS_CBSIZE CONFIG_INITRD_TAG CONFIG_OF_LIBFDT CONFIG_SYS_BOOTM_LEN $EXTRA_CONFIGS"

# Reset changes
pushd $_UBOOT_DIR >/dev/null
git checkout -- include/configs/$_CONFIG_FILE

# FIXME: mkimage build error with host-side libfdt-dev, we can remove libfdt-dev or simply disable mkimage build
echo "LOG: Disable mkimage to fix up build error with host side libfdt-dev"
git checkout -- tools/Makefile
sed -i -e "/hostprogs-.*mkimage/s/^/# /g" tools/Makefile

popd 2>/dev/null

# Update the new one
# Insert the new configs in the end of the external #if .. #endif condition
sed -i -e "/ROBIN INSERT START/,/ROBIN INSERT END/d" $CONFIG_FILE

line=$(grep -n "#endif" $CONFIG_FILE | tail -1 | cut -d':' -f1)

sed -i -e "${line}i/* ROBIN INSERT END */" $CONFIG_FILE

for config in $CONFIGS; do
	value=$(eval echo \$${config})

	grep -q "^#define $config" $CONFIG_FILE
	if [ $? -eq 0 ]; then
		sed -i -e "s%^#define $config[^\\]*\([\\]*\)$%#define $config\t${value}\1%g" $CONFIG_FILE
	else
		sed -i -e "${line}i#define ${config}\t${value}" $CONFIG_FILE
	fi
	grep "^#define $config" $CONFIG_FILE
done

sed -i -e "${line}i/* ROBIN INSERT START */" $CONFIG_FILE

sed -i -e "${line}i#endif" $CONFIG_FILE
sed -i -e "${line}i#undef CONFIG_BOOTCOMMAND" $CONFIG_FILE
sed -i -e "${line}i#ifdef CONFIG_BOOTCOMMAND" $CONFIG_FILE

pushd $_UBOOT_DIR >/dev/null
if [ ${1}X = "uboot"X ]; then
	# make qemu_arm64_defconfig 2>/dev/null
	# make -j32 2>/dev/null
	popd 2>/dev/null
fi
################ config.sh

do_ubootimg() {
	if [ "${BOOTDEV}" == "pflash" -o "${BOOTDEV}" == "flash" ]; then
		echo "** U-BOOT img **"
		[ -f $PFLASH_IMG ] && rm -rf $PFLASH_IMG

		truncate -s $(($PFLASH_SIZE * 1024))K $PFLASH_IMG

		[ -n "$KERNEL_IMAGE" -a -f "$KERNEL_IMAGE" ] && dd if=$KERNEL_IMAGE of=$PFLASH_IMG status=none seek=$(($ENV_SIZE * 1024 / $PFLASH_BS)) conv=notrunc bs=${PFLASH_BS}K
		echo "kernel image seek:$(($ENV_SIZE * 1024 / $PFLASH_BS))"
		echo "KERNEL_IMAGE:${KERNEL_IMAGE} \n\r DTB_IMAGE:${DTB_IMAGE}"
		[ -n "$ROOT_IMAGE" -a -f "$ROOT_IMAGE" ] && dd if=$ROOT_IMAGE of=$PFLASH_IMG status=none conv=notrunc seek=$((($ENV_SIZE + $KRN_SIZE) * 1024 / $PFLASH_BS)) bs=${PFLASH_BS}K

		[ -n "$DTB_IMAGE" -a -f "$DTB_IMAGE" ] && dd if=$DTB_IMAGE of=$PFLASH_IMG status=none conv=notrunc seek=$((($ENV_SIZE + $KRN_SIZE + $RDK_SIZE) * 1024 / $PFLASH_BS)) bs=${PFLASH_BS}K
		echo "dtb seek:$((($ENV_SIZE + $KRN_SIZE) * 1024 / $PFLASH_BS))"

		# Save env to the last 1M of pflash
		if [ -n "$ENV_IMG" ]; then
			# truncate -s 1M $ENV_IMG
			echo "BOOT_CMD: $BOOT_CMD"
			# echo -e -n "bootcmdx=${BOOT_CMD}\0" >$ENV_IMG
			hexdump -C $ENV_IMG
			if [ -n "$ENV_IMG" ]; then
				dd if=$ENV_IMG of=$PFLASH_IMG bs=1M seek=$ENV_OFFSET conv=notrunc status=none
			fi
		fi

		sync
	fi

}
#------------------------------------------------------

do_running() {
	SUPPORT_DEBUG=N
	SUPPORT_NET=N
	set -x
	[ ${1}X = "debug"X -o ${2}X = "debug"X ] && ARGS+="-s -S "
	if [ ${1}X = "net"X -o ${2}X = "net"X ]; then
		ARGS+="-net tap "
		ARGS+="-device virtio-net-device,netdev=bsnet0,"
		ARGS+="mac=E0:FE:D0:3C:2E:EE "
		ARGS+="-netdev tap,id=bsnet0,ifname=bsTap0 "
	fi

	if [ ${1}X = "uboot"X ]; then
		# Load pflash for booting with uboot every time
		# pflash is at least used as the env storage
		# unit=1 means the second pflash, the first one is unit=0
		# KERNEL_BOOT=" -bios /home/ubuntu/workspace/BiscuitOS/output/BiscuitOS-uboot/u-boot/u-boot/u-boot.bin -device loader,file=${ENV_IMG},addr=$ENV_ADDR -drive if=pflash,file=${PFLASH_IMG},format=raw,unit=1 -drive if=none,file=${ROOT_IMAGE}/rootfs.ext4,format=raw,id=virtio-vda -device virtio-blk-device,drive=virtio-vda "
		ARGS+="-device virtio-net-device,netdev=usernet -netdev user,id=usernet,hostfwd=tcp:127.0.0.1:6666-:22 "

		KERNEL_BOOT=" -bios ${ROOT}/u-boot/u-boot.bin -device loader,file=${ENV_IMG},addr=$ENV_ADDR -drive if=pflash,file=${PFLASH_IMG},format=raw,unit=1  -device virtio-blk-device,drive=hd1 -drive if=none,file=${ROOT}/Freeze.img,format=raw,id=hd1 -device virtio-blk-device,drive=hd0 -drive if=none,file=${ROOT}/BiscuitOS.img,format=raw,id=hd0 "
		APPEND=
		U_CMDLINE=
		sudo ${QEMUT} \
			-M virt,gic-version=3,its=on,iommu=smmuv3 \
			-m ${RAM_SIZE}M \
			-cpu cortex-a72 \
			-smp 4 \
			${KERNEL_BOOT} ${APPEND} ${U_CMDLINE} \
			-nographic \
			-fsdev local,path=${HOSTSHARE},security_model=passthrough,id=fsdev0 -device virtio-9p-device,fsdev=fsdev0,mount_tag=hostshare \
			${ARGS}
	else
		ARGS+="-device virtio-net-device,netdev=usernet -netdev user,id=usernet,hostfwd=tcp:127.0.0.1:6666-:22 "
		KERNEL_BOOT=" -kernel ${KERNEL_IMAGE} -dtb ${DTB_IMAGE} -device virtio-blk-device,drive=hd1 -drive if=none,file=${ROOT}/Freeze.img,format=raw,id=hd1 -device virtio-blk-device,drive=hd0 -drive if=none,file=${ROOT}/BiscuitOS.img,format=raw,id=hd0 "

		U_CMDLINE=${CMDLINE}
		APPEND="-append"
		sudo ${QEMUT} \
			-M virt,gic-version=3,its=on,iommu=smmuv3\
			-m ${RAM_SIZE}M \
			-cpu cortex-a72 \
			-smp 4 \
			${KERNEL_BOOT} ${APPEND} "${U_CMDLINE}" \
			-nographic \
			-fsdev local,path=${HOSTSHARE},security_model=passthrough,id=fsdev0 -device virtio-9p-device,fsdev=fsdev0,mount_tag=hostshare \
			 ${ARGS}
	fi

}

do_package() {
	# sudo cp ${BUSYBOX}/_install/* ${OUTPUT}/rootfs/${ROOTFS_NAME} -raf
	sudo chown root.root ${OUTPUT}/rootfs/${ROOTFS_NAME}/* -R
	dd if=/dev/zero of=${OUTPUT}/rootfs/ramdisk bs=1M count=${ROOTFS_SIZE}
	${FS_TYPE_TOOLS} -E lazy_itable_init=1,lazy_journal_init=1 -F ${OUTPUT}/rootfs/ramdisk
	mkdir -p ${OUTPUT}/rootfs/tmpfs
	sudo mount -t ${FS_TYPE} ${OUTPUT}/rootfs/ramdisk \
		${OUTPUT}/rootfs/tmpfs/ -o loop
	sudo cp -raf ${OUTPUT}/rootfs/${ROOTFS_NAME}/* ${OUTPUT}/rootfs/tmpfs/
	sudo umount ${OUTPUT}/rootfs/tmpfs
	mv ${OUTPUT}/rootfs/ramdisk ${OUTPUT}/BiscuitOS.img
	rm -rf ${OUTPUT}/rootfs/tmpfs
}

do_mount() {
	mkdir -p ${ROOT}/FreezeDir
	mountpoint -q ${ROOT}/FreezeDir
	[ $? = 0 ] && echo "FreezeDir has mount!" && exit 0
	## Mount Image
	sudo mount -t ${FS_TYPE} ${ROOT}/Freeze.img ${ROOT}/FreezeDir -o loop >>/dev/null 2>&1
	sudo chown ${USER}.${USER} -R ${ROOT}/FreezeDir
	echo "=============================================="
	echo "FreezeDisk: ${ROOT}/Freeze.img"
	echo "MountDiret: ${ROOT}/FreezeDir"
	echo "=============================================="
}

do_umount() {
	mountpoint -q ${ROOT}/FreezeDir
	[ $? = 1 ] && return 0
	sudo umount ${ROOT}/FreezeDir >/dev/null 2>&1
}

# Lunching BiscuitOS
case $1 in
"pack")
	# Package BiscuitOS.img
	do_package
	;;
"debug")
	# Debugging BiscuitOS
	do_umount
	do_running debug
	;;
"net")
	# Establish Netwroking
	sudo ${NET_CFG}/bridge.sh
	sudo cp -rf ${NET_CFG}/qemu-ifup /etc
	sudo cp -rf ${NET_CFG}/qemu-ifdown /etc
	do_umount
	do_running net
	;;
"mount")
	# Mount Freeze Disk
	do_mount
	;;
"umount")
	# Umount Freeze Disk
	do_umount
	;;
*)
	# Default Running BiscuitOS
	if [ "$1" = "uboot" ]; then
		do_ubootimg
	fi
	do_umount
	do_running $1 $2
	;;
esac
