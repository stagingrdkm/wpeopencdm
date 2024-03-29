#!/bin/bash
set -e

TARGET_DIR_SUFFIX="reference_next_23_0_1_ACK"

######### Edit directory below where to find brcm tarballs
export TGZS_DIR=/shared/rdk/23.0.1/
#########
 
######### Build setup and repo sync
rm -rf m393$TARGET_DIR_SUFFIX
mkdir m393$TARGET_DIR_SUFFIX
cd m393$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/rdk/yocto_oe/manifests/bcm-accel-manifests -b dunfell -m rdkv-broadcom-va.xml
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
    "$TGZS_DIR/refsw_release_unified_URSR_23.0.1_20230505_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_23.0.1_20230505_3pips_broadcom.tgz"
    "$TGZS_DIR/stblinux-android13-5.15.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_23.0.1_20230505.tgz#downloads/"
    "$TGZS_DIR/svpfw_dsp_7218c.bin#downloads/svpfw_dsp.bin"
)

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done

# mask gn from meta-rdk-broadcom-generic-rdk
cat << EOF >> meta-rdk-cobalt/conf/layer.conf
BBMASK += "\${RDKROOT}/meta-rdk-broadcom-generic-rdk/meta-brcm-opensource/recipes-browser/chromium"
EOF

# fix refsw tarball reference and checksums
cat <<EOF >> meta-rdk-sagemcom/meta-sagemcom-generic/recipes-bsp/broadcom-refsw/broadcom-tarball-location-and-hashes.inc

# replace comcast 3pip
SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/23_0_1/refsw_release_unified_URSR_23.0.1_20230505_3pips_comcast/refsw_release_unified_URSR_23.0.1_20230505_3pips_comcast.tgz;name=3pip"
SRC_URI += "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/23/refsw_release_unified_URSR_23_20221220_3pips_comcast_no_dolby_vision/2.1/refsw_release_unified_URSR_23.0.1_20230505_3pips_broadcom.tgz;name=3pip"
SRC_URI[3pip.md5sum] = "bf9f53dbae535d176658ebd0f50aa714"
SRC_URI[3pip.sha256sum] = "86e5ed4c766d222f8120f4a9dd327d0fee9beefd1a5889876be424a50d3e8ed4"

# replace svpfw_dsp.bin
SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/Dev_Tools/components/23.0.1/svpfw_dsp.bin;name=firmware"
SRC_URI += "https://127.0.0.1/svpfw_dsp.bin;name=firmware"
SRC_URI[firmware.md5sum] = "4cebefa3da9e8ae51f91638c9dab68e1"
SRC_URI[firmware.sha256sum] = "53fcf5be5a2a525036321523f78f9d1b5bc03735d114d63c145110f103d0b225"

# change the tarball checksums
SRC_URI[ursr.md5sum] = "ae3f8ef3360070d129d2a024aba3e2d5"
SRC_URI[ursr.sha256sum] = "8932b134cad90d7e3b9e4e7f85dd24c759cee05d634891bb3df8c6354d8a3615"

# remove comcast specific tarball
#SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/23/refsw_release_unified_URSR_23_20221220-dbv/2.1/refsw_release_unified_URSR_23_20221220-dbv.tgz;name=dbv"
EOF

cat <<EOF >> meta-rdk-sagemcom/meta-sagemcom-generic/recipes-bsp/broadcom-refsw/broadcom-refsw_unified-23.0.1-generic-rdk.bbappend

include broadcom-tarball-location-and-hashes.inc
EOF

cat <<EOF >> meta-rdk-sagemcom/meta-sagemcom-generic/recipes-bsp/broadcom-refsw/broadcom-refsw-driver_unified-23.0.1-generic-rdk.bbappend 

include broadcom-tarball-location-and-hashes.inc
EOF

cat << 'EOF' >> _build.sh

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

export MACHINE="m393-72180ZB-stb"

. ./meta-cmf-video-reference-next/setup-environment

cat << 'EOD' >> conf/local.conf

BBMASK += "${RDKROOT}/meta-rdk-brcm/recipes-bsp/broadcom-refsw"
BBMASK += "${RDKROOT}/meta-rdk-broadcom-generic-rdk/meta-brcm-opensource/recipes-browser/chromium"
IMAGE_FSTYPES_append = " ext2.gz"

BB_NUMBER_THREADS = "${@oe.utils.cpu_count() * 3 // 2}"
PARALLEL_MAKE = "-j ${@oe.utils.cpu_count() * 3 // 2}"

# Uncomment below lines to have debugging tools in the image
#WHITELIST_GPL-3.0_append    = " ${MLPREFIX}gdb ${MLPREFIX}gdbserver"
#WHITELIST_LGPL-3.0_append   = " ${MLPREFIX}gdb ${MLPREFIX}gdbserver"
#IMAGE_INSTALL_append        = " ${MLPREFIX}gdb ${MLPREFIX}gdbserver ${MLPREFIX}strace ${MLPREFIX}tcpdump ${MLPREFIX}rsync ${MLPREFIX}sudo"

EOD

if ! grep -q meta-rdk-cobalt conf/bblayers.conf; then
  echo 'BBLAYERS =+ "\${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf
fi

echo "bitbake -k lib32-rdk-generic-reference-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd m393$TARGET_DIR_SUFFIX; source _build.sh"
