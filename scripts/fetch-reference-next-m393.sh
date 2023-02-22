#!/bin/bash
set -e

TARGET_DIR_SUFFIX="reference-next"

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


checkout_repo() {
  if [ ! -d $2 ] ; then
     git clone $1/$2 $3
  fi
  cd $3
  git checkout $4
  cd -
}

#repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b dunfell -m rdkv-nosrc.xml
#repo sync --no-clone-bundle -j12

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next-dunfell.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

mkdir rdkmanifests
cp .repo/manifests/reference/auto.conf ./rdkmanifests/auto.conf
cp .repo/manifests/reference/cmf_revision.txt ./rdkmanifests/cmf_revision.txt

checkout_repo https://code.rdkcentral.com/r/collaboration/oem/sagemcom/yocto_oe/layers meta-rdk-oem-sagemcom-m393genac meta-rdk-sagemcom rdk-next 
#checkout_repo https://code.rdkcentral.com/r/collaboration/soc/broadcom/yocto_oe/layers meta-rdk-broadcom-next meta-rdk-broadcom-generic-rdk rdk-next 
#checkout_repo https://code.rdkcentral.com/r/collaboration/soc/broadcom/yocto_oe/layers meta-rdk-soc-broadcom meta-rdk-soc-broadcom stable2 
#mv meta-rdk-oem-sagemcom-m393genac meta-rdk-sagemcom

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
#sed -i "s/STB_lowpowermode_5.45.patch'/STB_lowpowermode_5.45.patch;apply=no'/" meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/meta-rdk-ext/recipes-connectivity/bluez5/bluez5_5.45.bbappend


# TODO: check why this is needed
cp meta-rdk-sagemcom/meta-sagemcom-top-m393-72180ZB-stb/conf/machine/m393-72180ZB-stb.conf meta-rdk-sagemcom/meta-sagemcom-top-m393-72180ZB-stb/conf/machine/m393-72180zb-stb.conf
sed -i 's/m393-72180ZB-stb/m393-72180zb-stb/' meta-rdk-sagemcom/meta-sagemcom-top-m393-72180ZB-stb/recipes-kernel/sc-devicetree/sc-devicetree.bbappend

# add some extra space
echo 'IMAGE_ROOTFS_EXTRA_SPACE = "500000"' >> meta-cmf-video-reference/recipes-core/images/rdk-generic-reference-image-brcm.inc

# fix image name in script
sed -i 's/rdk-generic-mediaclient-image/rdk-generic-reference-image/' meta-rdk-sagemcom/scripts/gen-upgrade-rdk.sh  

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

./meta-rdk-sagemcom/scripts/configure-sagemcom-reference.sh -y dunfell -B 22.0.1 -M m393-72180ZB-stb -D rdkcmf-dev

source ./build-m393-72180ZB-stb-sdk22.0.1-rdkcmf-dev/activate.sh

sed -i 's/INHERIT/#INHERIT/' ../openembedded-core/meta/conf/sanity.conf

sed -i 's/m393-72180ZB-stb/m393-72180zb-stb/' conf/local.conf
rm conf/auto.conf
touch conf/auto.conf
echo "require conf/distro/include/reference.inc" >> conf/local.conf

echo "bitbake -k rdk-generic-reference-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd m393$TARGET_DIR_SUFFIX; source _build.sh"
