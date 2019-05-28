#!/bin/sh
for x in 9 8 7 6 5 4 3 2 1 0
do
echo "restarting pc$x"
ssh pc$x 'sudo init 6'
done
