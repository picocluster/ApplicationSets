#!/bin/sh
for x in 4 3 2 1 0
do
echo "resizing pc$x"
ssh pc$x 'sudo ./resize_rockpi.sh'
done
