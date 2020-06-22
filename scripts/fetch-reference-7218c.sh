#!/bin/bash
set -e

TARGET_DIR_SUFFIX=""
if [ -z "$1" ]; then
  CONF_HW_REV="zb"
else
  CONF_HW_REV="$1"
  TARGET_DIR_SUFFIX="_$CONF_HW_REV"
fi

if [ "$CONF_HW_REV" != "ne" ] && [ "$CONF_HW_REV" != "zb" ]; then
  echo "Unsupported CONF_HW_REV: $CONF_HW_REV"
  exit
fi

echo "***** SETTING UP for HW_REV = $CONF_HW_REV *****"
echo "(pass zb or ne as argument to change)"
sleep 1

######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/data/rdk/19.2.1/
#########
 
######### Build setup and repo sync
rm -rf 7218c_reference$TARGET_DIR_SUFFIX
mkdir 7218c_reference$TARGET_DIR_SUFFIX
cd 7218c_reference$TARGET_DIR_SUFFIX

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

    "$TGZS_DIR/refsw_release_unified_URSR_19.2.1_20200201.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_19.2.1_20200203-wlan_1_20_1.tgz#downloads/"
    "$TGZS_DIR/stblinux-4.9-1.15.tar.bz2#downloads/"
    "$TGZS_DIR/applibs_release_DirectFB_hal-1.7.6.src-2.1.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_19.2.1_20200201_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_19.2.1_20200201_3pip_broadcom.tgz"
)

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done

##### cherry picks
## none at the moment

######### update checksums, LG specific!
sed -i 's/38b81d1bad718bf8c3e937749935dbef/d1f8331d52356f4942d5df9214364455/' meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-bsp/broadcom-refsw/3pips/broadcom-refsw_unified-19.2.1-generic-rdk.bbappend
sed -i 's/11f0d0dede527c355db0459a1a4145e85a8571dab5a5a7628e35a6baa174352d/9b45a8edd2a883e73e38d39ce97e5c490b7c169d4549c6d8e53424bc2536e1b8/' meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-bsp/broadcom-refsw/3pips/broadcom-refsw_unified-19.2.1-generic-rdk.bbappend
 
sed -i 's/7eb654c171c383ab4a3b81f1a4f22f4b/7eb654c171c383ab4a3b81f1a4f22f4b/' meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-bsp/broadcom-refsw/broadcom-refsw_unified-19.2.1-generic-rdk.bb
sed -i 's/ad54233f648725820042b0dcc92a37a5b41c2562493852316861aa5cf130ff32/ad54233f648725820042b0dcc92a37a5b41c2562493852316861aa5cf130ff32/' meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-bsp/broadcom-refsw/broadcom-refsw_unified-19.2.1-generic-rdk.bb
 
sed -i 's/7eb654c171c383ab4a3b81f1a4f22f4b/7eb654c171c383ab4a3b81f1a4f22f4b/' meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-dtcp/dtcp_unified-19.2.1.bbappend
sed -i 's/ad54233f648725820042b0dcc92a37a5b41c2562493852316861aa5cf130ff32/ad54233f648725820042b0dcc92a37a5b41c2562493852316861aa5cf130ff32/' meta-rdk-broadcom-generic-rdk/meta-brcm-refboard/recipes-dtcp/dtcp_unified-19.2.1.bbappend

## re-enable ld-is-gold
sed -i 's/DISTRO_FEATURES_remove_arm = "ld-is-gold"/#DISTRO_FEATURES_remove_arm = "ld-is-gold"/' meta-rdk/conf/distro/include/rdkv.inc

############# AAMP with OCDM #########
## config for aamp
cat <<EOF >> meta-rdk-broadcom-generic-rdk/meta-wpe-metrological/recipes-extended/aamp/aamp_git.bbappend
EXTRA_OECMAKE += " -DCMAKE_USE_RDK_PLUGINS=1"
EXTRA_OECMAKE += " -DCMAKE_CDM_DRM=1"
EXTRA_OECMAKE += "\${@bb.utils.contains('DISTRO_FEATURES', 'systemd', ' -DCMAKE_SYSTEMD_JOURNAL=1', '', d)}"
EXTRA_OECMAKE += " -DCMAKE_USE_THUNDER_OCDM_API_0_2=1"
PACKAGECONFIG[opencdm] = "-DCMAKE_USE_OPENCDM=1,-DCMAKE_USE_OPENCDM=0,wpeframework"
PACKAGECONFIG[playready] = "-DCMAKE_USE_PLAYREADY=1,-DCMAKE_USE_PLAYREADY=0,wpeframework"
PACKAGECONFIG[widevine] = "-DCMAKE_USE_WIDEVINE=1,-DCMAKE_USE_WIDEVINE=0,wpeframework"
PACKAGECONFIG[clearkey] = "-DCMAKE_USE_CLEARKEY=1,-DCMAKE_USE_CLEARKEY=0,wpeframework"
PACKAGECONFIG[opencdm_adapter] = "-DCMAKE_USE_OPENCDM_ADAPTER=1,-DCMAKE_USE_OPENCDM_ADAPTER=0,wpeframework"
PACKAGECONFIG_append = " opencdm_adapter playready widevine clearkey"
EOF
cat <<EOF > meta-rdk-broadcom-generic-rdk/meta-wpe-metrological/recipes-extended/aamp/gst-plugins-rdk-aamp_git.bbappend
PACKAGECONFIG[opencdm_adapter]  = "-DCMAKE_CDM_DRM=ON -DCMAKE_USE_OPENCDM_ADAPTER=ON,,"
PACKAGECONFIG_append = " opencdm_adapter"
EOF
####################################

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

####### copy missing files from LG layers - NE support. Drop this entire part in case you want ZB support.
if [ "$CONF_HW_REV" == "ne" ]; then
  download_list_ne=(
    # format: from#to
    # where:
    #  - from: is a src path
    #  - to: is either dst directory or dst path name
    "s3://lgi-onemw-staging/dev-tools/rdk2.0/downloads/SAGESW_7216B0_NE_Nagra_4_1_3_E1_LibertyGlo_5330.tar.gz#downloads/"
    "s3://lgi-onemw-staging/dev-tools/rdk2.0/downloads/SVPFW_HVD_2_27_12_0_7216B0_NE_E1.tgz#downloads/"
    "s3://lgi-onemw-staging/dev-tools/rdk2.0/downloads/SVPFW_RAVE_1_8_0_7216B0_NE_E1.tar.gz#downloads/"
  )

  for i in ${download_list_ne[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
  done

  git clone git@github.com:LibertyGlobal/meta-lgi-7218c
  cp meta-lgi-7218c/meta-rdk-broadcom-generic-rdk/meta-brcm-generic-rdk/recipes-bsp/broadcom-refsw/broadcom-refsw-unified-19.2.1-generic-rdk/CS9324411-fix-frontend-v00-boards.patch meta-rdk-broadcom-generic-rdk/meta-brcm972180hbc/recipes-bsp/broadcom-refsw/broadcom-refsw/
  cp meta-lgi-7218c/meta-rdk-broadcom-generic-rdk/meta-brcm-generic-rdk/recipes-bsp/broadcom-refsw/broadcom-refsw-unified-19.2-generic-rdk/nexus_regver_stub_key.c meta-rdk-broadcom-generic-rdk/meta-brcm972180hbc/recipes-bsp/broadcom-refsw/broadcom-refsw/
  cp meta-lgi-7218c/meta-rdk-broadcom-generic-rdk/meta-brcm-generic-rdk/recipes-bsp/broadcom-refsw/broadcom-refsw-unified-19.2-generic-rdk/nexus_regver_stub_signatures.c meta-rdk-broadcom-generic-rdk/meta-brcm972180hbc/recipes-bsp/broadcom-refsw/broadcom-refsw/
  cat <<EOF >> meta-rdk-broadcom-generic-rdk/meta-brcm972180hbc/recipes-bsp/broadcom-refsw/broadcom-refsw_unified-19.2.1-generic-rdk.bbappend
# SAGE for Nagra, Playready, Widevine
SAGEBIN_FILENAME="SAGESW_7216B0_NE_Nagra_4_1_3_E1_LibertyGlo_5330.tar.gz"
SRC_URI += "http://127.0.0.1/\${SAGEBIN_FILENAME};name=sage_bin;unpack=0"
SRC_URI[sage_bin.md5sum] = "24ccff3ad05a5991d575eb96c113ff52"
SRC_URI[sage_bin.sha256sum] = "2dde578bae9afb3f9a98d2c7b9b60048ffa0be88b8630ad2c73b41cf52f8b799"
SAGESDL := "\${SAGEBIN_FILENAME}"
 
# Signed SVPFW bins
SVPFW_HVD_BIN_FILENAME="SVPFW_HVD_2_27_12_0_7216B0_NE_E1.tgz"
SRC_URI += "http://127.0.0.1/\${SVPFW_HVD_BIN_FILENAME};name=svpfw_hvd_bin;unpack=0"
SRC_URI[svpfw_hvd_bin.md5sum] = "84e8e04503ea6d94a67f4536a032e6ce"
SRC_URI[svpfw_hvd_bin.sha256sum] = "aa94f475096a094c243fa97ec7247b0fcaf3d3f6a44fea9db74886e241e3c34e"
 
SVPFW_RAVE_BIN_FILENAME="SVPFW_RAVE_1_8_0_7216B0_NE_E1.tar.gz"
SRC_URI += "http://127.0.0.1/\${SVPFW_RAVE_BIN_FILENAME};name=svpfw_rave_bin;unpack=0"
SRC_URI[svpfw_rave_bin.md5sum] = "5464d889b1921c1622ce926493295880"
SRC_URI[svpfw_rave_bin.sha256sum] = "99d708677bfde2e01c0da72d5739d70608b9b9d1d9c2863846bd8aa0f668bee3"
 
do_install_prepend(){
        mkdir \${WORKDIR}/SAGESW_7218
        for file in \${SAGESDL}; do echo \$file; tar xzf \${S}/\$file --strip-components 1 -C \${WORKDIR}/SAGESW_7218; done
        cp -rf \${WORKDIR}/SAGESW_7218/sage* \${S}/obj.\${NEXUS_PLATFORM}/bin/.
 
        mkdir \${WORKDIR}/SVPFW_7218
        echo \${SVPFW_HVD_BIN_FILENAME};  tar xzf \${S}/\${SVPFW_HVD_BIN_FILENAME}  -C \${WORKDIR}/SVPFW_7218
        echo \${SVPFW_RAVE_BIN_FILENAME}; tar xzf \${S}/\${SVPFW_RAVE_BIN_FILENAME} -C \${WORKDIR}/SVPFW_7218
        cp -rf \${WORKDIR}/SVPFW_7218/svpfw* \${S}/obj.\${NEXUS_PLATFORM}/bin/.
}
 
SRC_URI += "file://nexus_regver_stub_key.c"
SRC_URI += "file://nexus_regver_stub_signatures.c"
SRC_URI += "file://CS9324411-fix-frontend-v00-boards.patch"
do_compile_prepend() {
    cp -f \${S}/nexus_regver_stub_key.c \${S}/nexus/modules/security/secv2/src
    cp -f \${S}/nexus_regver_stub_signatures.c \${S}/nexus/modules/security/secv2/src
}
EOF
fi

cat <<EOF >> _build.sh
######### brcm972180hbc build
declare -x MACHINE="brcm972180hbc-refboard"
declare -x RDK_ENABLE_64BIT="n"
declare -x RDK_ENABLE_AMAZON="n"
declare -x RDK_ENABLE_BMON="n"
declare -x RDK_ENABLE_BT_BLUEZ="n"
declare -x RDK_ENABLE_BT_FLUORIDE="n"
declare -x RDK_ENABLE_COBALT="n"
declare -x RDK_ENABLE_DEBUG_BUILD="y"
declare -x RDK_ENABLE_DTCP="n"
declare -x RDK_ENABLE_DTCP_SAGE="n"
declare -x RDK_ENABLE_NEXUS_USER_MODE="n"
declare -x RDK_ENABLE_SSTATE_MIRRORS_MODE="n"
declare -x RDK_ENABLE_SVP="y"
declare -x RDK_FETCH_FROM_DMZ="n"
declare -x RDK_URSR_VERSION="19.2.1"
declare -x RDK_7218_VERSION="B0"
declare -x RDK_USING_WESTEROS="y"
declare -x RDK_WITH_RESTRICTED_COMPONENTS="n"
declare -x RDK_ENABLE_WPE_METROLOGICAL="y"
declare -x RDK_WITH_OPENCDM="y"
 
. ./meta-rdk-broadcom-generic-rdk/setup-environment-refboard-rdkv
grep conf/local.conf -e "reference.inc" || echo "require conf/distro/include/reference.inc" >>  conf/local.conf

echo 'SPLASH = ""' >> conf/local.conf
echo 'IMAGE_FSTYPES += "ext2.gz"' >> conf/local.conf

echo RUN FOLLOWING TO BUILD: bitbake rdk-generic-reference-image
echo "PS1: you will need playready 3/4 key for playready encrypted content here: /home/root/playready3x.bin"
echo "PS2: use aamp-cli to test some streams (make sure to export AAMP_ENABLE_WESTEROS_SINK=1) :"
echo "  CLEAR: http://amssamples.streaming.mediaservices.windows.net/683f7e47-bd83-4427-b0a3-26a6c4547782/BigBuckBunny.ism/manifest(format=mpd-time-csf)"
echo "  PLAYREADY: https://bitmovin-a.akamaihd.net/content/art-of-motion_drm/mpds/11331.mpd"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference$TARGET_DIR_SUFFIX; source _build.sh"
