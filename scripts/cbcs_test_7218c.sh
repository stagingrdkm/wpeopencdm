#!/bin/bash
set -e

######### Edit directory below where to find brcm tarballs
export TGZS_DIR=/shared/rdk/23.0.1/
#########
 
######### Build setup and repo sync
rm -rf cbcs_test_7218c$TARGET_DIR_SUFFIX
mkdir cbcs_test_7218c$TARGET_DIR_SUFFIX
cd cbcs_test_7218c$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/rdk/yocto_oe/manifests/bcm-accel-manifests -b feature-cbcs-thunder42-07072023 -m rdkv-broadcom-va.xml
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

#####

cat << 'EOF' > _build.sh
######### brcm972180hbc build
export MACHINE="brcm972180hbc-refboard"
export RDK_URSR_VERSION="23.0.1";
export REFSW_3PIP_MD5="fee02520329dd89f51b01a1da7cfdbe3"
export REFSW_3PIP_SHA256="a5f65eb968a092c15744bae62bd070d08c37c345512efa8c8a640e9ea29a7c1e"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. meta-rdk-brcm/setup-environment-64bit-mc

cat << 'EOD' >> conf/local.conf

BBMASK += "${RDKROOT}/meta-rdk-brcm/recipes-bsp/broadcom-refsw"
BBMASK += "${RDKROOT}/meta-rdk-broadcom-generic-rdk/meta-brcm-opensource/recipes-browser/chromium"
IMAGE_FSTYPES_append = " ext2.gz"

BB_NUMBER_THREADS = "${@oe.utils.cpu_count() * 3 // 2}"
PARALLEL_MAKE = "-j ${@oe.utils.cpu_count() * 3 // 2}"

EOD

if [ "$(grep conf/bblayers.conf -e meta-rdk-cobalt -c)" -eq "0" ];
then
  echo 'BBLAYERS =+ "${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf
fi

echo "bitbake -k lib32-rdk-generic-mediaclient-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd cbcs_test_7218c$TARGET_DIR_SUFFIX; source _build.sh"
echo "                                    bitbake lib32-rdk-generic-mediaclient-image"
