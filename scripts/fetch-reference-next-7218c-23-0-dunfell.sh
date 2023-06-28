#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_next"
if [ ! -z "$NETFLIX" ]; then
    echo "NETFLIX BUILD !!"
    TARGET_DIR_SUFFIX="_netflix_next"
fi

######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/shared/rdk/23/
#########
 
######### Build setup and repo sync
rm -rf 7218c_reference_23_0_dunfell$TARGET_DIR_SUFFIX
mkdir 7218c_reference_23_0_dunfell$TARGET_DIR_SUFFIX
cd 7218c_reference_23_0_dunfell$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next-dunfell.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

mkdir rdkmanifests
cp .repo/manifests/reference/auto.conf ./rdkmanifests/auto.conf
cp .repo/manifests/reference/cmf_revision.txt ./rdkmanifests/cmf_revision.txt

if [ ! -z "$NETFLIX" ]; then
    # add extra netflix repos
    git clone "https://code.rdkcentral.com/r/apps/netflix/rdk-oe/meta-rdk-netflix"
    mkdir apps/netflix/ -p
    (cd apps/netflix/ && git clone "https://code.rdkcentral.com/r/apps/netflix/netflix-plugin")
    (cd apps/netflix/ && git clone "https://code.rdkcentral.com/r/apps/netflix/netflix-5.1.1")
    (cd apps/netflix/ && git clone "https://code.rdkcentral.com/r/apps/netflix/netflix-5.3.1")
fi

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
    "$TGZS_DIR/stblinux-5.4-1.10.tar.bz2#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_23_20221220_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_23_20221220_3pips_broadcom.tgz"
)
if [ ! -z "$NETFLIX" ]; then
    download_list+=("$TGZS_DIR/nrd-5.1.1-1340856.tar.gz#downloads/"
                    "$TGZS_DIR/nrd-5.3.1-27d5e9003f.tar.gz#downloads/")
fi

for i in ${download_list[@]}; do
    IFS='#' read -a args <<< $i
    from=${args[0]}
    to=${args[1]}
    download_file "${from}" "${to}"
done

##### cherry picks
 # RDKCMF-8908 Fix lib32-lvm2 packaging error
 (cd meta-rdk-ext && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-ext refs/changes/10/85410/1 && git cherry-pick FETCH_HEAD)

 # RDKDEV-774 DAC-sec omi-proxy for Thunder
 (cd meta-rdk-video && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-video refs/changes/75/86775/1 && git cherry-pick FETCH_HEAD)

 #RDKDEV-774 Add kernel configuration for OMI service
 (cd meta-cmf && git fetch https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-cmf refs/changes/43/87343/2 && git cherry-pick FETCH_HEAD)

 # RDKDEV-774 DAC-sec libkwk-rdk-data (Don't merge)
 (cd meta-cmf-restricted && git fetch https://code.rdkcentral.com/r/components/restricted/rdk-oe/meta-cmf-restricted refs/changes/76/86776/1 && git cherry-pick FETCH_HEAD)


if [ ! -z "$NETFLIX" ]; then
    # netflix integration commit
    (cd meta-cmf-video-reference-next && git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference-next" refs/changes/93/49193/8 && git cherry-pick FETCH_HEAD)
fi

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

cat << 'EOF' > _build.sh
######### brcm972180hbc build
export MACHINE="brcm972180hbc-refboard"
export RDK_URSR_VERSION="23.0"
export REFSW_3PIP_MD5="fee02520329dd89f51b01a1da7cfdbe3"
export REFSW_3PIP_SHA256="a5f65eb968a092c15744bae62bd070d08c37c345512efa8c8a640e9ea29a7c1e"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. ./meta-cmf-video-reference-next/setup-environment

cat << 'EOD' >> conf/local.conf

MODE_64="aarch64"

DISTRO_FEATURES_append=" libglvnd-as-stubs-provider"

BB_NUMBER_THREADS = "${@oe.utils.cpu_count() * 3 // 2}"
PARALLEL_MAKE = "-j ${@oe.utils.cpu_count() * 3 // 2}"

# Comment out below lines to have debugging tools in the image
#WHITELIST_GPL-3.0_append    = " ${MLPREFIX}gdb ${MLPREFIX}gdbserver"
#WHITELIST_LGPL-3.0_append   = " ${MLPREFIX}gdb ${MLPREFIX}gdbserver"
#IMAGE_INSTALL_append        = " ${MLPREFIX}gdb ${MLPREFIX}gdbserver ${MLPREFIX}strace ${MLPREFIX}tcpdump ${MLPREFIX}rsync ${MLPREFIX}sudo"

# Comment out for enabling OMI in the image
#IMAGE_INSTALL_append = " ${MLPREFIX}omi libkwk-rdk-data ${MLPREFIX}omi-test ${MLPREFIX}libmntfsimg-test ${MLPREFIX}libdacjwt-test"
#PREFERRED_PROVIDER_virtual/${MLPREFIX}libkwk="libkwk-rdk"

DISTRO_FEATURES_append=" DOBBY_CONTAINERS"
DISTRO_FEATURES_append=" DAC-sec"
IMAGE_INSTALL_append = " libkwk-rdk-data"

EOD

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference_23_0_dunfell$TARGET_DIR_SUFFIX; source _build.sh"
