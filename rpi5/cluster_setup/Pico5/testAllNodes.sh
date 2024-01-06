#!/bin/sh
for x in 4 3 2 1 0
do
echo "testing pc$x"
ssh pc$x 'df -h'
done
