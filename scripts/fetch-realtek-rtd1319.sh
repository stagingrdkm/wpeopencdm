#!/bin/bash
set -e

TARGET_DIR_SUFFIX=""

######### Build setup and repo sync
rm -rf realtekrtd1319$TARGET_DIR_SUFFIX
mkdir realtekrtd1319$TARGET_DIR_SUFFIX
cd realtekrtd1319$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/collaboration/soc/realtek/rtd-accel-manifests -b rdk-next -m rdk-next-rtk.xml
repo sync -j `nproc` --no-clone-bundle --no-tags

# add cobalt meta layer to fix issue with gn/protoc for libcobalt
git clone https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-cobalt

# we don't want to build amazon prime
rm -rf meta-rdk-amazon

# update patch
cp ../$(dirname $0)/patches/0002-AAMP-Pass-Height-and-Width.patch meta-rdk-soc-realtek/meta-cmf-mediabox/recipes-extended/aamp/files/

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

#source meta-rdk-soc-realtek/setup-environment mediaclient-mediabox --drm-restricted --rdk-netflix --rdk-ui --rdk-voice
source meta-rdk-soc-realtek/setup-environment mediaclient-mediabox --rdk-ui 

if ! grep -q meta-rdk-cobalt conf/bblayers.conf; then
  echo 'BBLAYERS =+ "\${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf
fi

echo 'DISTRO_FEATURES_remove="alexa-sdk-3.0"' >> conf/local.conf
echo 'DISTRO_FEATURES_append = " rialto"' >> conf/local.conf

echo "bitbake -k rdk-generic-mediaclient-westeros-wpe-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd realtekrtd1319$TARGET_DIR_SUFFIX; source _build.sh"
