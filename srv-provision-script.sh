#!/bin/bash

#########################################
########### srv-provision ################
#########################################

#manual step 1: get eth0 ip of srv
#manual step 2: copy ssh public key onto srv
#manual step 3: erase public key off srv when done

#input the srv ip address
echo " 
Welcome to SRV-Provision.  

Before executing this script make sure you have completed the following:

1) determined SRV IP address
2) copied Ansible ssh public key onto SRV
3) added SRV IP address to Ansible hosts file
"
read -p "Enter the IP of the SRV you wish to provision today: " SRV

#make folder for serial number
serial=`ssh root@${SRV} "dmidecode -s system-serial-number"`

mkdir -p /tmp/${serial}

#run first playbook: make julio directory, transfer data bundle, run install
ansible-playbook /etc/ansible/playbooks/srv-provision1.yml --extra-vars target="${SRV}"

#fetch csr
scp root@${SRV}:/etc/pki/srv/*.csr /tmp/${serial}/

#create root password
pass=`openssl rand -base64 6`

#place root password in serial-number directory
echo ${pass} >> /tmp/${serial}/${serial}-password.txt

#clear all text past "password:" in playbook
sed -i 's/\password:.*/password:/' /etc/ansible/playbooks/srv-provision2.yml      

#hash root password
HASH=`openssl passwd -crypt "${pass}"`

#place hashed root password in playbook
sed -i '/password:/s/$/ '"${HASH}"'/' /etc/ansible/playbooks/srv-provision2.yml 

#run 2nd playbook: yum install srv, change root password
ansible-playbook /etc/ansible/playbooks/srv-provision2.yml --extra-vars target="${SRV}"

#run 3rd playbook: set static ip, reboot server
ansible-playbook /etc/ansible/playbooks/srv-provision3.yml --extra-vars target="${SRV}"

echo " 
SRV-Provision has completed successfully.

The CSR and root password for this SRV have been stored in /tmp/${serial}.

Perform the following manual operations before shipping to customer:
    
1) test root password
2) test web interface
3) test SFP modules
4) test a faceplate
5) erase Ansible ssh public key (rm -rf /root/.ssh/authorized_keys)
6) dump the filesystem  (/usr/sbin/fsDump.sh)
7) ensure the cd drive is empty
8) shutdown the system from gui
" 
