#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_rdkshell"
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
export TGZS_DIR=/shared/rdk/19.2.1/
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

# fetch reference image layer
git clone git@github.com:sverkoye/meta-cmf-reference.git

# force tip of forked rdkservices repo
(rm -rf components/opensource/rdkservices; cd components/opensource; git clone git@github.com:sverkoye/rdkservices.git)

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

rm -rf meta-wpe

cat <<EOF >> _build.sh
declare -x MACHINE="brcm972180hbc-refboard"
. ./meta-cmf-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference$TARGET_DIR_SUFFIX; source _build.sh"