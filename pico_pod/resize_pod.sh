#!/bin/bash

part=`fdisk -l /dev/mmcblk1 | grep mmcblk1p1 | awk '{print $2}'`
echo "Found the start point of mmcblk1p1: $p2_start"
fdisk /dev/mmcblk1 << __EOF__ >> /dev/null
d
n
p
1
$part


w
__EOF__

sync
partprobe /dev/mmcblk1
resize2fs /dev/mmcblk1p1
echo "Resize complete"
