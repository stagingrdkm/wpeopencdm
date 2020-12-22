#!/bin/bash
set -e

TARGET_DIR_SUFFIX=""

######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/shared/rdk/19.2.1/
#########
 
######### Build setup and repo sync
rm -rf vip7802-accel$TARGET_DIR_SUFFIX
mkdir vip7802-accel$TARGET_DIR_SUFFIX
cd vip7802-accel$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/collaboration/oem/commscope/comm-bcm-accel-manifests -b rdk-next -m vip7802.xml
repo sync --no-tags -c --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)
sed -i 's/wget/#wget/' meta-rdk-oem-comm-bcm-accel/meta-vip7802/setup-environment-arris-generic-rdkv

function download_file() {
    local from="$1"
    local to="$2"

    mkdir -p $(dirname ${to})

    if [[ ${from} == s3://* ]]; then
	aws s3 cp "${from}" "${to}"
    else
	rsync -aP "${from}" "${to}"
    fi

    if [ -d "${to}" ]; then
	local downloaded="${to}/$(basename "${from}").done"
    else
	local downloaded="${to}.done"
    fi

    if [ ! -f "${downloaded}" ]; then
	touch "${downloaded}"
    fi
}

download_list=(
    # format: from#to
    # where:
    #  - from: is a src path
    #  - to: is either dst directory or dst path name

    "$TGZS_DIR/refsw_release_unified_URSR_19.2.1_20200201.tgz#downloads/refsw_release_unified_URSR_19.2.1_20200201-2.1.tgz"
    "$TGZS_DIR/stblinux-4.9-1.15.tar.bz2#downloads/stblinux-4.9-1.15-2.1.tar.bz2"
    "$TGZS_DIR/applibs_release_DirectFB_hal-1.7.6.src-2.1.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_19.2.1_20200201_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_19.2.1_20200201_3pips_comcast-2.1.tgz"
)

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done

##### cherry picks

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
######### vip7802-accel build
declare -x RDK_WITH_OPENCDM="y"
. meta-rdk-oem-comm-bcm-accel/meta-vip7802/setup-environment-arris-generic-rdkv
echo bitbake -k rdk-generic-mediaclient-image 
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd vip7802-accel$TARGET_DIR_SUFFIX; source _build.sh"
