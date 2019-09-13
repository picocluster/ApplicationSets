#!/bin/bash

# The number of nodes
cnt=$(($1 - 1))

# Define up new gateway
ip_new_start=$((100+cnt))

# Arrays holding origin and new IP addresses
ip_origin=()
ip_new=()

# From last node to head node
for i in $(seq 0 1 $cnt)
do
	# Get original IP
	ip=$(ssh pc$i '$(hostname -i | cut -d. -f4)')
	ip_origin+=($ip)
	# Get new IP
	ip_new+=($ip_new_start)
	ip_new_start=$((ip_new_start+1))
done


# From last node to head node
for i in $(seq $cnt -1 0)
do
d '
ssh pc$i << EOF
sudo su
echo "Iteration: "$i"This is host "`hostname`
cp /etc/netplan/eth0.yaml /etc/netplan/eth0.yaml.copy
sed -i 's/${ip_origin[$i]}/${ip_new[$i]}/g' /etc/netplan/eth0.yaml
cat /etc/netplan/eth0.yaml
#applying the config
nohup netplan apply > /dev/null 2>&1  &
EOF
sudo sed -i "s/${ip_origin[$i]}/${ip_new[$i]}/g" /etc/hosts
'
echo ${ip_origin[$i]},${ip_new[$i]}
done

#modifying /etc/hosts file
cat /etc/hosts

