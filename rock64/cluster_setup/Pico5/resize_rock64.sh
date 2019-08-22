sgdisk -e /dev/mmcblk1
sgdisk -d 7 /dev/mmcblk1
sgdisk -N 7 /dev/mmcblk1
partprobe /dev/mmcblk1
resize2fs /dev/mmcblk1p7
