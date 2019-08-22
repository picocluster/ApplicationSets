#!/bin/bash

part=`fdisk -l /dev/mmcblk0 | grep mmcblk0p2 | awk '{print $2}'`
echo "Found the start point of mmcblk0p2: $p2_start"
fdisk /dev/mmcblk0 << __EOF__ >> /dev/null
d
2
n
p
2
$part

p
w
__EOF__

sync
partprobe /dev/mmcblk0
resize2fs /dev/mmcblk0p2
echo "Resize complete"
