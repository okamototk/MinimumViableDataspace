#!/bin/sh

# Waiting if vault server is not started.
while true ;
do
        vault status 
        [[ $? -eq 1 ]] || break
done

# Initialize vault
vault operator init -key-shares=3 > /home/vault/init-tmp


# If Initialize is successed, keep seal-keys.
if [ $? -eq 0 ]
then
        mv /home/vault/init-tmp /vault/data/seal-keys
else
        rm /home/vault/init-tmp
fi

# Unseal
for i in 1 2 3
do
        vault operator unseal $(grep "Key $i" /vault/data/seal-keys |sed 's/Unseal Key '$i': //i') 
done
