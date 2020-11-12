#!/bin/bash
# awk -F '"' '/192/{print $2;exit;}' ../terraform/terraform.tfstate | tee inventory
# grep -o '"192.*"' ../terraform/terraform.tfstate | tr -d '"' | uniq | tee inventory
terraform output -state="../terraform/terraform.tfstate" ips | grep -o '".*"' | tr -d '"' | uniq | tee inventory
