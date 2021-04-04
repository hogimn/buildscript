#
# Copyright (C) 2010 Samsung Electronics Co., Ltd.
#              http://www.samsung.com/
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
####################################
#!/bin/bash

dmesg | tail -10

echo "Input SD Reader's device file?(ex. /dev/sdb)"

read SD_Type

if [ -z $SD_Type ]
then
    echo "usage: <SD Reader's device file>"
    exit 0
fi

partition1="$SD_Type"1
partition2="$SD_Type"2
partition3="$SD_Type"3
partition4="$SD_Type"4

if [ -b $SD_Type ]
then
    echo "$SD_Type reader is identified."
else
    echo "$SD_Type is NOT identified."
    exit 0
fi

####################################
TFLASH=$SD_Type
# Check TFlash Sectors
TFLASH_SECTORS=`fdisk -l -u $SD_Type | grep sectors | head -n 1 \
| cut -d',' -f4 | cut -d' ' -f3`

# Android Partition Size 
SIZE_ANDROID=524288		# 256MB
SIZE_ANDROID_DATA=2097152	# 1GB
SIZE_ANDROID_CACHE=262144	# 128MB
SIZE_FAT=$(($TFLASH_SECTORS- 32768 - $SIZE_ANDROID - $SIZE_ANDROID_DATA - $SIZE_ANDROID_CACHE)) 

OFFSET_ANDROID=$(($SIZE_ANDROID-1))
OFFSET_ANDROID_DATA=$(($SIZE_ANDROID_DATA-1))
OFFSET_ANDROID_CACHE=$(($SIZE_ANDROID_CACHE-1))
OFFSET_FAT=$(($SIZE_FAT-1))

echo "TFLASH_SECTORS $TFLASH_SECTORS"
echo "FAT_SIZE $SIZE_FAT"


####################################
echo "T-Flash-device:$TFLASH"

print_success()
{
    if [ "$1" == 0 ]; then
        echo "success"
    else
        echo "failed"
        exit -1
    fi
}

partition_add()
{
    echo n
    echo p
    echo $1
    echo $2
    echo +$3
}

sdcard_format()
{
# JNJ
    START_ANDROID=32768  # 16MB
    START_ANDROID_DATA=$(($START_ANDROID+$SIZE_ANDROID))
    START_ANDROID_CACHE=$(($START_ANDROID_DATA+$SIZE_ANDROID_DATA))
    START_FAT=$(($START_ANDROID_CACHE+$SIZE_ANDROID_CACHE))

# Pre Umount 
    umount /media/*

    (

# Pre Partition Delete
        echo d
        echo 6
        echo d
        echo 5
        echo d
        echo 4
        echo d
        echo 3
        echo d
        echo 2
        echo d
        echo 1
        echo d

# Partition Create
        partition_add 1 $START_FAT $OFFSET_FAT
        partition_add 2 $START_ANDROID $OFFSET_ANDROID
        partition_add 3 $START_ANDROID_DATA $OFFSET_ANDROID_DATA
        partition_add 4 $START_ANDROID_CACHE $OFFSET_ANDROID_CACHE

        echo w
        echo q
    ) | fdisk -u $TFLASH > /dev/null 2>&1

# Partition Format
    echo "FAT Partition Format"
    mkfs.vfat -n "Storage" "$TFLASH"1 > /dev/null 2>&1
    echo "Android Partition Format"
    mkfs.ext4 -L "android" "$TFLASH"2 > /dev/null 2>&1
    echo "Data Partition Format"
    mkfs.ext4 -L "data" "$TFLASH"3 > /dev/null 2>&1
    echo "Cache Partition Format"
    mkfs.ext4 -L "cache" "$TFLASH"4 > /dev/null 2>&1
}

echo
echo -n "Erase Uboot and Kernel Area : "

echo
echo -n "Partition Create : "
sdcard_format
print_success "$?"

####################################
#<BL1 fusing>
bl1_position=1		# 32 sector,16KB(0x4000)
uboot_position=33	# 1024 sector, 512KB(0x80000)
kernel_position=1120	# 4MB
logo_position=9312	# 2MB
rootfs_position=13408      # 1.2MB

dd bs=512 seek=1 if=/dev/zero of=$TFLASH count=32768 > /dev/null 2>&1

echo "BL1 fusing"
split -b 16368 ./Image/u-boot.bin bl1
wine AttachHeader.exe bl1aa u-boot-bl1.bin
rm bl1a*
dd iflag=dsync oflag=dsync if=./u-boot-bl1.bin of=$SD_Type seek=$bl1_position
print_success "$?"
rm u-boot-bl1.bin

####################################
#<u-boot fusing>
echo "u-boot fusing"
dd iflag=dsync oflag=dsync if=./Image/u-boot.bin of=$SD_Type seek=$uboot_position
print_success "$?"

#<kernel fusing>
echo "kernel fusing"
dd iflag=dsync oflag=dsync if=./Image/zImage of=$SD_Type seek=$kernel_position count=8192
print_success "$?"

#<logo fusing>
#echo "logo fusing"
#dd iflag=dsync oflag=dsync if=./Image/hanback_logo.bmp of=$SD_Type seek=$logo_position count=4096
#print_success "$?"

#<root ramdisk fusing>
echo "root ramdisk fusing"
dd iflag=dsync oflag=dsync if=./Image/ramdisk-uboot.img of=$SD_Type seek=$rootfs_position count=4096
print_success "$?"


#<Android FileSystem>
echo "Filesystem system Copy.."
rm -rf temp
mkdir temp
mount "$SD_Type"2 temp
cp -a ./Image/system/* ./temp/
sync
umount ./temp
print_success "$?"

##########
#<Data filesystem>
echo "Filesystem data Copy.."
mount "$SD_Type"3 temp
cp -r ./Image/data/* ./temp/
umount temp
print_success "$?"

##########
#<Storage filesystem>
echo "Filesystem Storage Copy.."
mount "$SD_Type"1 temp
cp -r ./Image/storage/* ./temp/
sleep 2
umount temp
print_success "$?"
rm -rf temp

####################################
#<Message Display>
echo "Image is fused successfully."
echo "Eject SD card and insert it again."
