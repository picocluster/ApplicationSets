#!/bin/bash

sgdisk -e /dev/mmcblk0
sgdisk -d 1 /dev/mmcblk0
sgdisk -N 1 /dev/mmcblk0
partprobe /dev/mmcblk0
resize2fs /dev/mmcblk0p1
