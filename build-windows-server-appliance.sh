#!/bin/bash -x

echo "Building Windows Server Virtual Appliance ..."
rm -f output-vmware-iso/*

packer build -var-file=windows-server-appliance-builder.json windows-server-appliance.json

