#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_23_0_1_ACK_CBCSb"

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


# CBCS changes
# jump to latest R2?
(cd meta-rdk-video && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-video refs/changes/70/85770/4 && git cherry-pick FETCH_HEAD)
# gst svp ext changes
#git fetch https://code.rdkcentral.com/r/rdk/components/generic/gst_svp_ext refs/changes/67/85767/2 && git cherry-pick FETCH_HEAD
# gstreamer change for cbcs
(cd meta-rdk-ext && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext refs/changes/69/85769/1 && git cherry-pick FETCH_HEAD)


# remove wpeframework patch
(cd meta-rdk-ext && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext refs/changes/88/86288/2 && git cherry-pick FETCH_HEAD)
# add 2 webkitbrowser patches
(cd meta-rdk && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk refs/changes/87/86287/2 && git cherry-pick FETCH_HEAD)
# HUGE cleanup and R4 support
(cd meta-rdk-video && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-video refs/changes/17/86317/4 && git cherry-pick FETCH_HEAD)
# meta-cmf-video renames
(cd meta-cmf-video && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video refs/changes/27/86327/4 && git cherry-pick FETCH_HEAD)

# amazon changes
#(cd meta-rdk-amazon && git fetch https://code.rdkcentral.com/r/apps/amazon/rdk-oe/meta-rdk-amazon refs/changes/97/86697/1 && git cherry-pick FETCH_HEAD)
# R4 support
(cd meta-cmf-video && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video refs/changes/98/86698/1 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-video && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video refs/changes/25/86425/1 && git cherry-pick FETCH_HEAD)

# AMLogic
#(cd meta-amlogic && git fetch https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers/meta-amlogic refs/changes/00/86700/1 && git cherry-pick FETCH_HEAD)
#(cd imeta-rdk-bsp-amlogic && git fetch https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers/meta-rdk-bsp-amlogic refs/changes/01/86701/1 && git cherry-pick FETCH_HEAD)
#(cd meta-rdk-aml && git fetch https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers/meta-rdk-aml refs/changes/99/86699/1 && git cherry-pick FETCH_HEAD)

# RPi
#(cd meta-cmf-raspberrypi && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-cmf-raspberrypi refs/changes/24/86424/1 && git cherry-pick FETCH_HEAD)

# fixes
(cd meta-rdk-broadcom-generic-rdk && git fetch https://code.rdkcentral.com/r/soc/broadcom/yocto_oe/layers/meta-rdk-broadcom-next refs/changes/53/86653/5 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-video && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video refs/changes/33/86733/4 && git cherry-pick FETCH_HEAD)

#(cd meta-rdk-video && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-video refs/changes/92/86692/1 && git cherry-pick FETCH_HEAD) # done in 86317
#(cd meta-rdk-video && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-video refs/changes/30/86430/1 && git cherry-pick FETCH_HEAD) # done in 85770
#(cd meta-rdk-ext && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext refs/changes/29/86429/1 && git cherry-pick FETCH_HEAD) # done in 85769
#(cd meta-rdk-ext && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext refs/changes/27/86427/1 && git cherry-pick FETCH_HEAD) # done in 86288
#(cd meta-rdk && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk refs/changes/26/86426/1 && git cherry-pick FETCH_HEAD) # done in 86287
#(cd meta-cmf-video && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video refs/changes/23/86423/1 && git cherry-pick FETCH_HEAD) # done in 86327

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
SRC_URI[firmware.md5sum] = "27b34979560fd414c5834f6e92463200"
SRC_URI[firmware.sha256sum] = "956986517f769f34b574c730fe527f8f3bf18a3bebea1fe437b2539b5300e7bf"

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

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

export RDK_URSR_VERSION="23.0.1";
export RDK_ENABLE_64BIT="y"
export RDK_KERNEL_VERSION="5.15-1.0"
export MODE_64="aarch64" 
export REPO_MANIFEST_BRANCH="dunfell"

. meta-rdk-brcm-sagemcom/setup-environment

if ! grep -q meta-rdk-cobalt conf/bblayers.conf; then
  echo 'BBLAYERS =+ "\${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf
fi

echo 'DISTRO_FEATURES_append = " rialto"' >> conf/local.conf

echo "bitbake -k lib32-rdk-generic-mediaclient-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd m393$TARGET_DIR_SUFFIX; source _build.sh"
