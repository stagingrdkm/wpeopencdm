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

    # RDKDEV-774 Add runtime dependency for libkwk-data
    #(cd meta-cmf-restricted && git fetch https://code.rdkcentral.com/r/components/restricted/rdk-oe/meta-cmf-restricted refs/changes/30/90330/2 && git cherry-pick FETCH_HEAD)

    # 94463: RDKCMF-8285 Update sessionmgr sources (14c8af7d5) | https://code.rdkcentral.com/r/c/components/generic/sessionmgr/+/94463
    (cd components/generic/sessionmgr && git fetch https://code.rdkcentral.com/r/components/generic/sessionmgr refs/changes/63/94463/1 && git cherry-pick FETCH_HEAD)

    # 92323: RDKCMF-8285 Update gstreamer-cxx sources (14c8af7d5) | https://code.rdkcentral.com/r/c/components/generic/gstreamer-cxx/+/92323
    (cd components/generic/gstreamer-cxx && git fetch https://code.rdkcentral.com/r/components/generic/gstreamer-cxx refs/changes/23/92323/3 && git cherry-pick FETCH_HEAD)

    # 92247: RDKCMF-8285 Update websocket-ipplayer2-utils sources (14c8af7d5) | https://code.rdkcentral.com/r/c/components/generic/websocket-ipplayer2-utils/+/92247
    (cd components/generic/websocket-ipplayer2-utils && git fetch https://code.rdkcentral.com/r/components/generic/websocket-ipplayer2-utils refs/changes/47/92247/6 && git cherry-pick FETCH_HEAD)

    # 94371: RDKCMF-8285 Update websocket-ipplayer2 recipes (14c8af7d5) | https://code.rdkcentral.com/r/c/components/generic/rdk-oe/meta-cmf-video-restricted/+/94371
    (cd meta-cmf-video-restricted && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted refs/changes/71/94371/3 && git cherry-pick FETCH_HEAD)

    # 94236: RDKCMF-8285 Update websocket-ipplayer2 sources (14c8af7d5) | https://code.rdkcentral.com/r/c/components/generic/websocket-ipplayer2/+/94236
    (cd components/generic/websocket-ipplayer2 && git fetch https://code.rdkcentral.com/r/components/generic/websocket-ipplayer2 refs/changes/36/94236/9 && git cherry-pick FETCH_HEAD)

    # 92297: RDKCMF-8285 Update websocket-ipplayer2-api sources (14c8af7d5) | https://code.rdkcentral.com/r/c/components/generic/websocket-ipplayer2-api/+/92297
    (cd components/generic/websocket-ipplayer2-api && git fetch https://code.rdkcentral.com/r/components/generic/websocket-ipplayer2-api refs/changes/97/92297/6 && git cherry-pick FETCH_HEAD)
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

#INHERIT += "externalsrc"

#EXTERNALSRC_pn-websocket-ipplayer-client = "${@'${RDKROOT}/components/generic/websocket-ipplayer2'       if (os.path.isdir('${RDKROOT}/components/generic/websocket-ipplayer2'))       else ''}"

#EXTERNALSRC_pn-websocket-ipplayer2       = "${@'${RDKROOT}/components/generic/websocket-ipplayer2'       if (os.path.isdir('${RDKROOT}/components/generic/websocket-ipplayer2'))       else ''}"
#EXTERNALSRC_pn-websocket-ipplayer2-api   = "${@'${RDKROOT}/components/generic/websocket-ipplayer2-api'   if (os.path.isdir('${RDKROOT}/components/generic/websocket-ipplayer2-api'))   else ''}"
#EXTERNALSRC_pn-websocket-ipplayer2-utils = "${@'${RDKROOT}/components/generic/websocket-ipplayer2-utils' if (os.path.isdir('${RDKROOT}/components/generic/websocket-ipplayer2-utils')) else ''}"

#EXTERNALSRC_pn-sessionmgr                = "${@'${RDKROOT}/components/generic/sessionmgr'                if (os.path.isdir('${RDKROOT}/components/generic/sessionmgr'))                else ''}"

##EXTERNALSRC_pn-mabr-agent                = "${@'${RDKROOT}/components/generic/onemw-src'                 if (os.path.isdir('${RDKROOT}/components/generic/onemw-src'))                 else ''}"
##EXTERNALSRC_pn-mabr-agent-api            = "${@'${RDKROOT}/components/generic/onemw-src'                 if (os.path.isdir('${RDKROOT}/components/generic/onemw-src'))                 else ''}"

#IMAGE_INSTALL_append = " ${MLPREFIX}mabr-agent"

#IMAGE_INSTALL_append = " ${MLPREFIX}netsrvmgr"

EOD

if [ "$(grep conf/bblayers.conf -e meta-rdk-cobalt -c)" -eq "0" ];
then
  echo 'BBLAYERS =+ "${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf
fi

echo "bitbake -k lib32-rdk-generic-reference-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference_next_23_0_1_ACK$TARGET_DIR_SUFFIX; source _build.sh"
echo "                                    bitbake lib32-rdk-generic-reference-image"
