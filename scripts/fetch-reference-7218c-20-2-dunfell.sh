#!/bin/bash
set -e

TARGET_DIR_SUFFIX=""
######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/shared/rdk/20.2/
#########
 
######### Build setup and repo sync
rm -rf 7218c_reference_20_2_dunfell$TARGET_DIR_SUFFIX
mkdir 7218c_reference_20_2_dunfell$TARGET_DIR_SUFFIX
cd 7218c_reference_20_2_dunfell$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

rm -rf downloads
ln -sf ../downloads downloads

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next-dunfell.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

mkdir rdkmanifests
cp .repo/manifests/reference/auto.conf ./rdkmanifests/auto.conf
cp .repo/manifests/reference/cmf_revision.txt ./rdkmanifests/cmf_revision.txt

##### Add support for building brcm_manufacturing_tool
## use: bitbake -f -c manufacturing_tool broadcom-refsw
## not put automatically in image: brcm_manufacturing_tool and libb_sage_manufacturing.so
if [ -f ../patches/manufacturing-tool-compilation-fix.patch ]; then
  cp ../patches/manufacturing-tool-compilation-fix.patch meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-bsp/broadcom-refsw/broadcom-refsw-unified-19.2-generic-rdk/manufacturing-tool-compilation-fix.patch
  cat <<EOF >> meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-bsp/broadcom-refsw/3pips/broadcom-refsw_unified-19.2.1-generic-rdk.bbappend
SRC_URI += "file://manufacturing-tool-compilation-fix.patch"
do_manufacturing_tool() {
    export URSR_TOP=\${S}
    export B_REFSW_OS=linuxuser
    /bin/echo "Building manufacturing tool ..."
    oe_runmake -C  \${WORKDIR}/BSEAV/lib/security/sage/manufacturing/app USE_NXCLIENT=y IMAGE_NAME=sage_ta_manufacturing.bin re
}
addtask do_manufacturing_tool
EOF
fi
#####

cat <<EOF >> _build.sh
######### brcm972180hbc build
declare -x MACHINE="brcm972180hbc-refboard"
declare -x RDK_URSR_VERSION="20.2"
declare -x REFSW_3PIP_MD5="6ddc92c8a737e5f0c8ddd3bb1fc3b812"
declare -x REFSW_3PIP_SHA256="d60650ec4be7ac6e8d9bf1de243972251bdbc9ba37df38d586835242a8058fff"
declare -x ZBDSP_MD5="9dc5071d062d307e19c3295259f42e91"
declare -x ZBDSP_SHA256="bf65d4bf805af501a083da736d93c4ae3d0347078b6174f75575493235b6941a"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. ./meta-cmf-video-reference/setup-environment

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference_20_2_dunfell$TARGET_DIR_SUFFIX; source _build.sh"
