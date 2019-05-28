ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

#Copy the identity key to all of your other nodes.
for x in 1 2 3 4 5 0
do
ssh-copy-id -i .ssh/id_rsa.pub picocluster@pc$x
done
