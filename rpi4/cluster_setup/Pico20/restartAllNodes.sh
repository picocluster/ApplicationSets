#!/bin/sh
for x in 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
do
echo "restarting pc$x"
ssh pc$x 'sudo init 6'
done
