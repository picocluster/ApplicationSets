#!/bin/sh
for x in 4 3 2 1 0
do
echo "Setting up pc$x"
ssh pc$x 'sudo iptables -P FORWARD ACCEPT'
done
