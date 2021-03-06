#!/bin/bash
set -e

TARGET_DIR_SUFFIX=""
######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/shared/rdk/20.2/
#########
 
######### Build setup and repo sync
rm -rf 7218c_reference$TARGET_DIR_SUFFIX
mkdir 7218c_reference$TARGET_DIR_SUFFIX
cd 7218c_reference$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

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

    "$TGZS_DIR/refsw_release_unified_URSR_20.2_20201005.zb.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_20.2_20201005.tgz#downloads/"
    "$TGZS_DIR/stblinux-4.9-1.19.tar.bz2#downloads/"
    "$TGZS_DIR/applibs_release_DirectFB_hal-1.7.6.src-2.1.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_20.2_20201005_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_20.2_20201005_3pips_broadcom.tgz"
)

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done

##### cherry picks
## none

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
declare -x MACHINE="brcm972180hbc-refboard"
declare -x RDK_URSR_VERSION="20.2"
declare -x REFSW_3PIP_MD5="6ddc92c8a737e5f0c8ddd3bb1fc3b812"
declare -x REFSW_3PIP_SHA256="d60650ec4be7ac6e8d9bf1de243972251bdbc9ba37df38d586835242a8058fff"
declare -x ZBDSP_MD5="9dc5071d062d307e19c3295259f42e91"
declare -x ZBDSP_SHA256="bf65d4bf805af501a083da736d93c4ae3d0347078b6174f75575493235b6941a"
. ./meta-cmf-video-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference$TARGET_DIR_SUFFIX; source _build.sh"
