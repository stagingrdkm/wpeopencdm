#!/bin/bash
set -e

######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/shared/rdk/23.0.1/
#########
 
######### Build setup and repo sync
rm -rf 7218c_reference_next_23_0_1_ACK$TARGET_DIR_SUFFIX
mkdir 7218c_reference_next_23_0_1_ACK$TARGET_DIR_SUFFIX
cd 7218c_reference_next_23_0_1_ACK$TARGET_DIR_SUFFIX

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

#####
function apply_patches() {
    # Patches for DAC-sec functionality

    # RDKDEV-774 Enable DAC-sec distro feature in reference images
    (cd meta-cmf-video && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video refs/changes/32/90332/8 && git cherry-pick FETCH_HEAD)

    # RDKDEV-774 Add support for DAC-sec distro feature
    (cd meta-rdk-video && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-video refs/changes/75/86775/14 && git cherry-pick FETCH_HEAD)

    # RDKDEV-774 DAC-sec libkwk-rdk-data
    (cd meta-cmf-restricted && git fetch https://code.rdkcentral.com/r/components/restricted/rdk-oe/meta-cmf-restricted refs/changes/66/90266/4 && git cherry-pick FETCH_HEAD)

    # RDKDEV-774 Add runtime dependency for libkwk-data
    (cd meta-cmf-restricted && git fetch https://code.rdkcentral.com/r/components/restricted/rdk-oe/meta-cmf-restricted refs/changes/30/90330/2 && git cherry-pick FETCH_HEAD)

    # RDKDEV-774 Fix calling mContainerStoppedCb()
    (cd meta-cmf && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-cmf refs/changes/14/91014/1 && git cherry-pick FETCH_HEAD)

    # RDKCMF-8908 Fix lib32-lvm2 packaging error
    #(cd meta-rdk-ext && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext refs/changes/10/85410/2 && git cherry-pick FETCH_HEAD)

    # RDKCMF-8908 Fix lib32-lvm2 packaging error (stopgap)
    (cd meta-cmf-video && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video refs/changes/07/90907/2 && git cherry-pick FETCH_HEAD)
}

# Uncomment to enable patches for DAC-sec
#apply_patches


cat << 'EOF' > _build.sh
######### brcm972180hbc build
export MACHINE="brcm972180hbc-refboard"
export RDK_URSR_VERSION="23.0.1";
export RDK_ENABLE_64BIT="y"
export RDK_KERNEL_VERSION="5.15-1.0"
export MODE_64="aarch64" 
export REPO_MANIFEST_BRANCH="dunfell"
export REFSW_3PIP_MD5="fee02520329dd89f51b01a1da7cfdbe3"
export REFSW_3PIP_SHA256="a5f65eb968a092c15744bae62bd070d08c37c345512efa8c8a640e9ea29a7c1e"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. ./meta-cmf-video-reference-next/setup-environment

cat << 'EOD' >> conf/local.conf

PACKAGE_CLASSES = "package_rpm"
DISTRO_FEATURES_append = " libglvnd-as-stubs-provider"

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

echo "bitbake -k lib32-rdk-generic-reference-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference_next_23_0_1_ACK$TARGET_DIR_SUFFIX; source _build.sh"
echo "                                    bitbake lib32-rdk-generic-reference-image"
