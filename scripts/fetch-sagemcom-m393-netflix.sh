#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_netflix"

######### Edit directory below where to find brcm tarballs
export TGZS_DIR=/shared/rdk/22.01/
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
sed -i 's/rdk-dev/lgi-int/' meta-rdk-netflix/recipes-extended/netflix-src/netflix_6.1.1.bb

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

    "$TGZS_DIR/refsw_release_unified_URSR_22.0.1_20220411.tgz#downloads/refsw_release_unified_URSR_22_0_1_20220411-2.2.tgz"
    "$TGZS_DIR/stblinux-5.4-1.7.tar.bz2#downloads/"
    "$TGZS_DIR/SVPFW_DSP_22_0_11_BCM7216_B0_ZB_Automated_FW_Signing-4424_E1.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_22.0.1_20220411_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_22.0.1_20220411_3pips_broadcom.tgz"
    "/shared/rdk/netflix6/SDK-6.1.1.zip#downloads/"
)

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done


# remove sagemcom bbappend about stblinux tarballs
rm meta-rdk-sagemcom/meta-sagemcom-generic/recipes-kernel/stblinux/stblinux_5.4-1.7-generic-rdk.bbappend

# remove sysint bbappend because patch does not apply (is now commented out in bbappend)
#rm meta-rdk-sagemcom/meta-sagemcom-top-m393-72180ZB-stb/recipes-extended/sysint/sysint_git.bbappend

# fix refsw tarball reference and checksums
cat <<EOF >> meta-rdk-sagemcom/meta-sagemcom-generic/recipes-bsp/broadcom-refsw/broadcom-refsw_unified-22.0.1-generic-rdk.bbappend
SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/22_0_1/refsw_release_unified_URSR_22_0_1_20220411_3pips_comcast/2.1/refsw_release_unified_URSR_22_0_1_20220411_3pips_comcast-2.1.tgz;name=3pip"
SRC_URI += "https://\${RDK_ARTIFACTS_URL}/broadcom_restricted/22_0_1/refsw_release_unified_URSR_22_0_1_20220411_3pips_broadcom/2.1/refsw_release_unified_URSR_22.0.1_20220411_3pips_broadcom.tgz;name=3pip"
SRC_URI[3pip.md5sum] = "51277f72e15757a2769e074c38a63886"
SRC_URI[3pip.sha256sum] = "692eceed06797fb8f6171ed87a726506462cd8e4f71b499cf7fe1b60683d6092"

SRC_URI_remove = "https://\${RDK_ARTIFACTS_URL}/Dev_Tools/components/22.0.1/svpfw_dsp.bin;name=firmware"
SRC_URI += "file://SVPFW_DSP_22_0_11_BCM7216_B0_ZB_Automated_FW_Signing-4424_E1.tgz"

SRC_URI[ursr.md5sum] = "4738f2f3ee2f831cf87a015a774769b9"
SRC_URI[ursr.sha256sum] = "d5e22d4d5250bc9672fb98691680cac321c5ca73f87e3d8ef1546d9875696498"
EOF

# fix small patch issue in bluez
sed -i "s/STB_lowpowermode_5.45.patch'/STB_lowpowermode_5.45.patch;apply=no'/" meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/meta-rdk-ext/recipes-connectivity/bluez5/bluez5_5.45.bbappend

# do not apply openssl patch in Icrypto because it gives patch issues and we don't need it because we use Nexus impl
sed -i 's/^SRC_URI/#SRC_URI/' meta-rdk-netflix/recipes-extended/wpeframework-clientlibraries/wpeframework-clientlibraries_git.bbappend

# remove netflix thunder plugin because it is not yet building
sed -i 's/netflix-thunder-plugin//' meta-rdk-netflix/recipes-core/images/packagegroup-rdk-media-common.bbappend

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

./meta-rdk-sagemcom/scripts/configure-sagemcom-reference.sh -y dunfell -B 22.0.1 -M m393-72180ZB-stb -D rdkcmf-dev

source ./build-m393-72180ZB-stb-sdk22.0.1-rdkcmf-dev/activate.sh

echo "bitbake -k rdk-generic-mediaclient-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd m393$TARGET_DIR_SUFFIX; source _build.sh"
