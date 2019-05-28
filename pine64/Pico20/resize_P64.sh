#!/bin/bash

part=`fdisk -l /dev/mmcblk0 | grep mmcblk0p1 | awk '{print $2}'`
echo "Found the start point of mmcblk0p1: $p2_start"
fdisk /dev/mmcblk0 << __EOF__ >> /dev/null
d
n
p
1
$part


w
__EOF__

sync
partprobe /dev/mmcblk0
resize2fs /dev/mmcblk0p1
echo "Resize complete"
