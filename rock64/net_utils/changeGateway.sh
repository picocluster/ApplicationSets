#!/bin/bash

# The number of nodes
cnt=$(expr $1 - 1)

# Define up new gateway
gateway_origin=10.1.10
gateway_new=10.0.1

# From last node to head node
for i in $(seq $cnt -1 0)
do

ssh pc$i << EOF
sudo su
echo "Iteration: "$i"This is host "`hostname`
cp /etc/netplan/eth0.yaml /etc/netplan/eth0.yaml.copy
sed -i 's/${gateway_new}\}/${gateway_new}/g' /etc/netplan/eth0.yaml
cat /etc/netplan/eth0.yaml
#applying the config
nohup netplan apply > /dev/null 2>&1  &

EOF
done

#modifying /etc/hosts file
sudo sed -i "s/${gateway_origin}/${gateway_new}/g" /etc/hosts
cat /etc/hosts
exit 1

