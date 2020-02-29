sgdisk -e /dev/mmcblk0
sgdisk -d 5 /dev/mmcblk0
sgdisk -N 5 /dev/mmcblk0
partprobe /dev/mmcblk0
resize2fs /dev/mmcblk0p5
