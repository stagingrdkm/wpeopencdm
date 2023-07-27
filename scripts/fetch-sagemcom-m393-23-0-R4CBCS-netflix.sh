#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_23_0_CBCS_netflix"

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

repo init -u https://code.rdkcentral.com/r/collaboration/oem/sagemcom/sagemcom-m393genac-manifests -b rdk-next -m SGMM393_YOCTO_3_1_netflix-dev.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)
(cd meta-rdk-netflix && git checkout rdkgerrit/rdk-dev-nf6.1)
sed -i 's/rdk-dev/lgi-int/' meta-rdk-netflix/recipes-extended/netflix-src/netflix_6.1.2.bb

# CBCS changes
# jump to latest R2?
(cd meta-rdk-video && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-video refs/changes/70/85770/2 && git cherry-pick FETCH_HEAD)
# gst svp ext changes
#git fetch https://code.rdkcentral.com/r/rdk/components/generic/gst_svp_ext refs/changes/67/85767/2 && git cherry-pick FETCH_HEAD
# gstreamer change for cbcs
(cd meta-rdk-ext && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext refs/changes/69/85769/1 && git cherry-pick FETCH_HEAD)


# remove wpeframework patch
(cd meta-rdk-ext && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext refs/changes/88/86288/2 && git cherry-pick FETCH_HEAD)
# add 2 webkitbrowser patches
(cd meta-rdk && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk refs/changes/87/86287/1 && git cherry-pick FETCH_HEAD)
# HUGE cleanup and R4 support
(cd meta-rdk-video && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-video refs/changes/17/86317/2 && git cherry-pick FETCH_HEAD)
# meta-cmf-video renames
(cd meta-cmf-video && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video refs/changes/27/86327/3 && git cherry-pick FETCH_HEAD)

# fix
(cd meta-rdk-broadcom-generic-rdk && git fetch https://code.rdkcentral.com/r/soc/broadcom/yocto_oe/layers/meta-rdk-broadcom-next refs/changes/53/86653/4 && git cherry-pick FETCH_HEAD)

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
    "$TGZS_DIR/svpfw_dsp_7218c.bin#downloads/svpfw_dsp.bin"
    "/shared/rdk/netflix6/SDK-6.1.2.zip#downloads/"
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

# replace svpfw_dsp.bin
SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/Dev_Tools/components/23.0/svpfw_dsp.bin;name=firmware"
SRC_URI += "https://127.0.0.1/svpfw_dsp.bin;name=firmware"
SRC_URI[firmware.md5sum] = "27b34979560fd414c5834f6e92463200"
SRC_URI[firmware.sha256sum] = "956986517f769f34b574c730fe527f8f3bf18a3bebea1fe437b2539b5300e7bf"

# change the tarball checksums
SRC_URI[ursr.md5sum] = "11531f20152569819d8642b8b78937cc"
SRC_URI[ursr.sha256sum] = "90db94c90359e157835f56375aedccf1c66410c0c7bce42de5bd3f3864683ea4"

# remove comcast specific tarball
SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/23/refsw_release_unified_URSR_23_20221220-dbv/2.1/refsw_release_unified_URSR_23_20221220-dbv.tgz;name=dbv"
EOF

# do not apply openssl patch in Icrypto because it gives patch issues and we don't need it because we use Nexus impl
sed -i 's/^SRC_URI/#SRC_URI/' meta-rdk-netflix/recipes-extended/wpeframework-clientlibraries/wpeframework-clientlibraries_git.bbappend

# remove netflix thunder plugin because it is not yet building
sed -i 's/netflix-thunder-plugin//' meta-rdk-netflix/recipes-core/images/packagegroup-rdk-media-common.bbappend

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

./meta-rdk-sagemcom/scripts/configure-sagemcom-reference.sh -y dunfell -B 23.0 -M m393-72180ZB-stb -D rdkcmf-dev

source ./build-m393-72180ZB-stb-sdk23.0-rdkcmf-dev/activate.sh

if ! grep -q meta-rdk-cobalt conf/bblayers.conf; then
  echo 'BBLAYERS =+ "\${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf
fi

echo "bitbake -k rdk-generic-mediaclient-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd m393$TARGET_DIR_SUFFIX; source _build.sh"
