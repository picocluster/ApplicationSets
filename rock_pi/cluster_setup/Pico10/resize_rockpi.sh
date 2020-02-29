sgdisk -e /dev/mmcblk1
sgdisk -d 5 /dev/mmcblk1
sgdisk -N 5 /dev/mmcblk1
partprobe /dev/mmcblk1
resize2fs /dev/mmcblk1p5
