#!/bin/bash
declare -a host=`terraform output -state="../terraform/terraform.tfstate" names | grep -o '".*"' | tr -d '"' | uniq`
declare -a ip=`terraform output -state="../terraform/terraform.tfstate" ips | grep -o '".*"' | tr -d '"' | uniq`
if [ ${#ip[0]} == 0 ]
then
    echo "The tfstate file appears to be empty. Confirm that you have a running server (with terraform apply) and try again."
    exit 
else
    n=0
    for i in "${ip[@]}"
    do
        if [ $n == 0 ]
        then
            printf "[${host[n]}]\n$i\n" | tee inventory
        else
            printf "[${host[n]}]\n$i\n" | tee -a inventory
        fi
        n=$((n+1))
    done
fi
