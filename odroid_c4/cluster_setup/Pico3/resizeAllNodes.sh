#!/bin/sh
for x in 2 1 0
do
echo "resizing pc$x"
ssh pc$x 'sudo resize_c2.sh'
done
