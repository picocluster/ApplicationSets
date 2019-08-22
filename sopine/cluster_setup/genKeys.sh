ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

#Copy the identity key to all of your other nodes.
ssh-copy-id -i .ssh/id_rsa.pub picocluster@pc1
ssh-copy-id -i .ssh/id_rsa.pub picocluster@pc2
ssh-copy-id -i .ssh/id_rsa.pub picocluster@pc3
ssh-copy-id -i .ssh/id_rsa.pub picocluster@pc4
ssh-copy-id -i .ssh/id_rsa.pub picocluster@pc0
