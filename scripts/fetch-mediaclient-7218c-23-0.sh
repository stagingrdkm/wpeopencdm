#!/bin/bash
set -e

######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/shared/rdk/23/
#########
 
######### Build setup and repo sync
rm -rf 7218c_mediaclient_23_0$TARGET_DIR_SUFFIX
mkdir 7218c_mediaclient_23_0$TARGET_DIR_SUFFIX
cd 7218c_mediaclient_23_0$TARGET_DIR_SUFFIX

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

    "$TGZS_DIR/refsw_release_unified_URSR_23_20221220.tgz#downloads/"
    "$TGZS_DIR/stblinux-5.4-1.10.tar.bz2#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_23_20221220_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_23_20221220_3pips_broadcom.tgz"
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
export RDK_URSR_VERSION="23.0"
export REFSW_3PIP_MD5="fee02520329dd89f51b01a1da7cfdbe3"
export REFSW_3PIP_SHA256="a5f65eb968a092c15744bae62bd070d08c37c345512efa8c8a640e9ea29a7c1e"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. meta-rdk-brcm/setup-environment-64bit

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

if [ "$(grep conf/bblayers.conf -e meta-rdk-cobalt -c)" -eq "0" ];
then
  echo 'BBLAYERS =+ "${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf
fi

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_mediaclient_23_0$TARGET_DIR_SUFFIX; source _build.sh"
echo "                                    bitbake lib32-rdk-generic-mediaclient-image"
