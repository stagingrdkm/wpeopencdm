#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_23_0"

######### Edit directory below where to find brcm tarballs
export TGZS_DIR=/shared/rdk/23/
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

repo init -u https://code.rdkcentral.com/r/collaboration/oem/sagemcom/sagemcom-m393genac-manifests -b rdk-next -m default_collaboration_3_1.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

#mkdir rdkmanifests
#cp .repo/manifests/reference/auto.conf ./rdkmanifests/auto.conf
#cp .repo/manifests/reference/cmf_revision.txt ./rdkmanifests/cmf_revision.txt

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
    "$TGZS_DIR/stblinux-5.4-1.10.tar.bz2#downloads/stblinux-5.4-1.10-2.1.tar.bz2"
    "$TGZS_DIR/refsw_release_unified_URSR_23_20221220_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_23_20221220_3pips_broadcom.tgz"
)

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done

# add cobalt meta layer to fix issue with gn/protoc for libcobalt
git clone https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-cobalt

# mask gn from meta-rdk-broadcom-generic-rdk
cat << EOF >> meta-rdk-cobalt/conf/layer.conf
BBMASK += "\${RDKROOT}/meta-rdk-broadcom-generic-rdk/meta-brcm-opensource/recipes-browser/chromium"
EOF

# remove sagemcom bbappend about stblinux tarballs
rm meta-rdk-sagemcom/meta-sagemcom-generic/recipes-kernel/stblinux/stblinux_5.4-1.7-generic-rdk.bbappend

# fix refsw tarball reference and checksums
cat <<EOF >> meta-rdk-sagemcom/meta-sagemcom-generic/recipes-bsp/broadcom-refsw/broadcom-refsw_unified-23.0-generic-rdk.bbappend

# replace comcast 3pip
SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/23/refsw_release_unified_URSR_23_20221220_3pips_comcast_no_dolby_vision/2.1/refsw_release_unified_URSR_23_20221220_3pips_comcast_no_dolby_vision.tgz;name=3pip"
SRC_URI += "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/23/refsw_release_unified_URSR_23_20221220_3pips_comcast_no_dolby_vision/2.1/refsw_release_unified_URSR_23_20221220_3pips_broadcom.tgz;name=3pip"
SRC_URI[3pip.md5sum] = "fee02520329dd89f51b01a1da7cfdbe3"
SRC_URI[3pip.sha256sum] = "a5f65eb968a092c15744bae62bd070d08c37c345512efa8c8a640e9ea29a7c1e"

# remove svpfw_dsp.bin
SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/Dev_Tools/components/23.0/svpfw_dsp.bin;name=firmware"

# change the tarball checksums
SRC_URI[ursr.md5sum] = "11531f20152569819d8642b8b78937cc"
SRC_URI[ursr.sha256sum] = "90db94c90359e157835f56375aedccf1c66410c0c7bce42de5bd3f3864683ea4"

# remove comcast specific tarball
SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/23/refsw_release_unified_URSR_23_20221220-dbv/2.1/refsw_release_unified_URSR_23_20221220-dbv.tgz;name=dbv"

# fake svpfw_dsp.bin
do_install_prepend() {
    touch \${WORKDIR}/svpfw_dsp.bin
}
EOF

cat << EOF >> meta-rdk-sagemcom/meta-sagemcom-generic/recipes-wpeframework-clientlibraries/wpeframework-clientlibraries/wpeframework-clientlibraries_git.bbappend
# add patch for correct repo, patch is in meta-rdk-broadcom-next but remove in bbappend in
# https://code.rdkcentral.com/r/plugins/gitiles/collaboration/soc/broadcom/yocto_oe/layers/meta-rdk-broadcom-next/+/9c64a00e7a891c865fa1f4142583daef23e689f0
SRC_URI += "file://0001-Update-Icrypto-Nexus-repo.patch"
EOF

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

./meta-rdk-sagemcom/scripts/configure-sagemcom-reference.sh -y dunfell -B 23.0 -M m393-72180ZB-stb -D rdkcmf-dev

source ./build-m393-72180ZB-stb-sdk23.0-rdkcmf-dev/activate.sh

echo 'BBLAYERS =+ "\${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf

echo "bitbake -k rdk-generic-mediaclient-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd m393$TARGET_DIR_SUFFIX; source _build.sh"
