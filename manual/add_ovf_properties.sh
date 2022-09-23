#!/bin/bash

OUTPUT_PATH="../output-vmware-iso"
OVF_PATH=${OUTPUT_PATH}

rm -f ${OUTPUT_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.mf

sed "s/{{VERSION}}/${APPLIANCE_VERSION}/g" windows-server.xml.template > windows-server.xml

if [ "$(uname)" == "Darwin" ]; then
    sed -i .bak1 's/<VirtualHardwareSection>/<VirtualHardwareSection ovf:transport="com.vmware.guestInfo">/g' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i .bak2 "/    <\/vmw:BootOrderSection>/ r windows-server.xml" ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i .bak3 '/^      <vmw:ExtraConfig ovf:required="false" vmw:key="nvram".*$/d' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i .bak4 "/^    <File ovf:href=\"${WINDOWS_SERVER_APPLIANCE_NAME}-file1.nvram\".*$/d" ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i .bak6 's/ovf:fileRef="file2"//g' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i .bak7 '/vmw:ExtraConfig.*/d' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
else
    sed -i 's/<VirtualHardwareSection>/<VirtualHardwareSection ovf:transport="com.vmware.guestInfo">/g' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i "/    <\/vmw:BootOrderSection>/ r windows-server.xml" ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i '/^      <vmw:ExtraConfig ovf:required="false" vmw:key="nvram".*$/d' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i "/^    <File ovf:href=\"${WINDOWS_SERVER_APPLIANCE_NAME}-file1.nvram\".*$/d" ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i 's#ovf:capacity="1"#ovf:capacity="${disk2size}"#g' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i 's/ovf:fileRef="file2"//g' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
    sed -i '/vmw:ExtraConfig.*/d' ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf
fi

ovftool --compress=9 ${OVF_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf ${OUTPUT_PATH}/${FINAL_WINDOWS_SERVER_APPLIANCE_NAME}.ova
rm -rf ${OUTPUT_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}.ovf ${OUTPUT_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}-disk1.vmdk ${OUTPUT_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}-disk2.vmdk ${OUTPUT_PATH}/${WINDOWS_SERVER_APPLIANCE_NAME}-file1.nvram
rm -f windows-server.xml
