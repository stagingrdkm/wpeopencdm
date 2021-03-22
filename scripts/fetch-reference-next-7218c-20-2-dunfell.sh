#!/bin/bash
set -e

TARGET_DIR_SUFFIX="_next"
if [ ! -z "$NETFLIX" ]; then
    echo "NETFLIX BUILD !!"
    TARGET_DIR_SUFFIX="_netflix_next"
fi

######### Edit directory below where to find 19.2 tarballs
export TGZS_DIR=/shared/rdk/20.2/
#########
 
######### Build setup and repo sync
rm -rf 7218c_reference_20_2_dunfell$TARGET_DIR_SUFFIX
mkdir 7218c_reference_20_2_dunfell$TARGET_DIR_SUFFIX
cd 7218c_reference_20_2_dunfell$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next.xml
(cd .repo/manifests/ && git fetch https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests refs/changes/46/54646/2 && git cherry-pick FETCH_HEAD)
sed -i 's/manifest-next.xml/manifest-next-dunfell.xml/' .repo/manifest.xml
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

    "$TGZS_DIR/refsw_release_unified_URSR_20.2_20201005.zb.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_20.2_20201005.tgz#downloads/"
    "$TGZS_DIR/stblinux-4.9-1.19.tar.bz2#downloads/"
    "$TGZS_DIR/applibs_release_DirectFB_hal-1.7.6.src-2.1.tgz#downloads/"
    "$TGZS_DIR/refsw_release_unified_URSR_20.2_20201005_3pips_libertyglobal.tgz#downloads/refsw_release_unified_URSR_20.2_20201005_3pips_broadcom.tgz"
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
if [ ! -z "$NETFLIX" ]; then
    # netflix integration commit
    (cd meta-cmf-video-reference-next && git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference-next" refs/changes/93/49193/8 && git cherry-pick FETCH_HEAD)
fi
(cd meta-cmf-video-reference && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference refs/changes/87/54287/3 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-video-reference-next && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference-next refs/changes/88/54288/4 && git cherry-pick FETCH_HEAD)

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

# fix 20.2 hashes
sed -i 's/d1f8331d52356f4942d5df9214364455/6ddc92c8a737e5f0c8ddd3bb1fc3b812/' meta-cmf-video-reference-next/conf/distro/include/reference.inc
sed -i 's/9b45a8edd2a883e73e38d39ce97e5c490b7c169d4549c6d8e53424bc2536e1b8/d60650ec4be7ac6e8d9bf1de243972251bdbc9ba37df38d586835242a8058fff/' meta-cmf-video-reference-next/conf/distro/include/reference.inc

sed -i 's/d1f8331d52356f4942d5df9214364455/6ddc92c8a737e5f0c8ddd3bb1fc3b812/' meta-cmf-video-reference/conf/distro/include/reference.inc
sed -i 's/9b45a8edd2a883e73e38d39ce97e5c490b7c169d4549c6d8e53424bc2536e1b8/d60650ec4be7ac6e8d9bf1de243972251bdbc9ba37df38d586835242a8058fff/' meta-cmf-video-reference/conf/distro/include/reference.inc

sed -i 's/19.2.1/20.2/' meta-cmf-video-reference/setup-environment
sed -i '/20.2/a   declare -x RDK_7218_SECURE_PART="ZB_REGION_VERIFICATION"' meta-cmf-video-reference/setup-environment
sed -i '/20.2/a   declare -x ZBDSP_MD5="9dc5071d062d307e19c3295259f42e91"' meta-cmf-video-reference/setup-environment
sed -i '/20.2/a   declare -x ZBDSP_SHA256="bf65d4bf805af501a083da736d93c4ae3d0347078b6174f75575493235b6941a"' meta-cmf-video-reference/setup-environment

cat <<EOF >> _build.sh
######### brcm972180hbc build
declare -x MACHINE="brcm972180hbc-refboard"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. ./meta-cmf-video-reference-next/setup-environment

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd 7218c_reference_20_2_dunfell$TARGET_DIR_SUFFIX; source _build.sh"
