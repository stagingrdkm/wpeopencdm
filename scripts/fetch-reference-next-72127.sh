#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_next"

######### Edit directory below where to find brcm tarballs
export TGZS_DIR=/shared/rdk/22.01/
#########
 
######### Build setup and repo sync
rm -rf 72127_reference$TARGET_DIR_SUFFIX
mkdir 72127_reference$TARGET_DIR_SUFFIX
cd 72127_reference$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next-dunfell.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

mkdir rdkmanifests
cp .repo/manifests/reference/auto.conf ./rdkmanifests/auto.conf
cp .repo/manifests/reference/cmf_revision.txt ./rdkmanifests/cmf_revision.txt

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

    "$TGZS_DIR/refsw_release_unified_URSR_22.0.1_20220411.tgz#downloads/"
    "$TGZS_DIR/stblinux-5.4-1.7.tar.bz2#downloads/"
    "$TGZS_DIR/SVPFW_DSP_22_0_11_BCM7216_B0_ZB_Automated_FW_Signing-4424_E1.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_22.0.1_20220411_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_22.0.1_20220411_3pips_broadcom.tgz"
)

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done

cat <<EOF >> _build.sh
######### brcm972127ott build
declare -x MACHINE="brcm972127ott-refboard"
#declare -x RDK_URSR_VERSION="22.0.1"
#declare -x RDK_KERNEL_VERSION="5.4-1.7"
#declare -x REFSW_3PIP_MD5="51277f72e15757a2769e074c38a63886"
#declare -x REFSW_3PIP_SHA256="692eceed06797fb8f6171ed87a726506462cd8e4f71b499cf7fe1b60683d6092"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. ./meta-cmf-video-reference-next/setup-environment

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 72127_reference$TARGET_DIR_SUFFIX; source _build.sh"
