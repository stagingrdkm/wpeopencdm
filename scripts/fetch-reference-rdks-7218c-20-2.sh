#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_rdks"
if [ -z "$1" ]; then
  CONF_HW_REV="zb"
else
  CONF_HW_REV="$1"
  TARGET_DIR_SUFFIX="${TARGET_DIR_SUFFIX}_$CONF_HW_REV"
fi

if [ "$CONF_HW_REV" != "ne" ] && [ "$CONF_HW_REV" != "zb" ]; then
  echo "Unsupported CONF_HW_REV: $CONF_HW_REV"
  exit
fi

echo "***** SETTING UP for HW_REV = $CONF_HW_REV *****"
echo "(pass zb or ne as argument to change)"
sleep 1

######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/shared/rdk/20.2/
#########
 
######### Build setup and repo sync
rm -rf 7218c_reference_20_2$TARGET_DIR_SUFFIX
mkdir 7218c_reference_20_2$TARGET_DIR_SUFFIX
cd 7218c_reference_20_2$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

mkdir rdkmanifests
cp .repo/manifests/reference/auto.conf ./rdkmanifests/auto.conf
cp .repo/manifests/reference/cmf_revision.txt ./rdkmanifests/cmf_revision.txt

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

    "$TGZS_DIR/refsw_release_unified_URSR_20.2_20201005.tgz#downloads/"
    "$TGZS_DIR/stblinux-4.9-1.19.tar.bz2#downloads/"
    "$TGZS_DIR/applibs_release_DirectFB_hal-1.7.6.src-2.1.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_20.2_20201005_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_20.2_20201005_3pips_broadcom.tgz"
)

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done

##### cherry picks
## none

##### Add support for building brcm_manufacturing_tool
## use: bitbake -f -c manufacturing_tool broadcom-refsw
## not put automatically in image: brcm_manufacturing_tool and libb_sage_manufacturing.so
if [ -f ../patches/manufacturing-tool-compilation-fix.patch ]; then
  cp ../patches/manufacturing-tool-compilation-fix.patch meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-bsp/broadcom-refsw/broadcom-refsw-unified-19.2-generic-rdk/manufacturing-tool-compilation-fix.patch
  cat <<EOF >> meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-bsp/broadcom-refsw/3pips/broadcom-refsw_unified-19.2.1-generic-rdk.bbappend
SRC_URI += "file://manufacturing-tool-compilation-fix.patch"
do_manufacturing_tool() {
    export URSR_TOP=\${S}
    export B_REFSW_OS=linuxuser
    /bin/echo "Building manufacturing tool ..."
    oe_runmake -C  \${WORKDIR}/BSEAV/lib/security/sage/manufacturing/app USE_NXCLIENT=y IMAGE_NAME=sage_ta_manufacturing.bin re
}
addtask do_manufacturing_tool
EOF
fi
#####

rm -rf meta-wpe

# fix 20.2 hashes
sed -i 's/d1f8331d52356f4942d5df9214364455/6ddc92c8a737e5f0c8ddd3bb1fc3b812/' meta-cmf-video-reference-next/conf/distro/include/reference.inc
sed -i 's/9b45a8edd2a883e73e38d39ce97e5c490b7c169d4549c6d8e53424bc2536e1b8/d60650ec4be7ac6e8d9bf1de243972251bdbc9ba37df38d586835242a8058fff/' meta-cmf-video-reference-next/conf/distro/include/reference.inc

sed -i 's/d1f8331d52356f4942d5df9214364455/6ddc92c8a737e5f0c8ddd3bb1fc3b812/' meta-cmf-video-reference/conf/distro/include/reference.inc
sed -i 's/9b45a8edd2a883e73e38d39ce97e5c490b7c169d4549c6d8e53424bc2536e1b8/d60650ec4be7ac6e8d9bf1de243972251bdbc9ba37df38d586835242a8058fff/' meta-cmf-video-reference/conf/distro/include/reference.inc

sed -i 's/19.2.1/20.2/' meta-cmf-video-reference/setup-environment
sed -i '/20.2/a   declare -x RDK_7218_SECURE_PART="ZB_WITHOUT_REGION_VERIFICATION"' meta-cmf-video-reference/setup-environment

cat <<EOF >> _build.sh
######### brcm972180hbc build
declare -x MACHINE="brcm972180hbc-refboard"
. ./meta-cmf-video-reference-next/setup-environment

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference_20_2$TARGET_DIR_SUFFIX; source _build.sh"
