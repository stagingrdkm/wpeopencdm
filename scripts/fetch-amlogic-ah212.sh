#!/bin/bash
set -e

TARGET_DIR_SUFFIX=""

######### Build setup and repo sync
rm -rf ah212$TARGET_DIR_SUFFIX
mkdir ah212$TARGET_DIR_SUFFIX
cd ah212$TARGET_DIR_SUFFIX

if [ -n "$(find "../../downloads" -maxdepth 2 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

[ -d downloads ] || mkdir -p downloads

repo init -u https://code.rdkcentral.com/r/collaboration/soc/amlogic/aml-accel-manifests -b rdk-next -m sc2-dunfell-k54-rdk-next.xml
repo sync -j4 --no-clone-bundle

# add cobalt meta layer to fix issue with gn/protoc for libcobalt
git clone https://code.rdkcentral.com/r/rdk/components/generic/rdk-oe/meta-rdk-cobalt


# remove unused package which gives parsing issue due to SRC_URI git checks
rm -f meta-amlogic/recipes-core/amlogic_sesg/aml-sesg_git.bb

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

# full command
# source meta-rdk-aml/set-env.sh mesonsc2-5.4-lib32-ah212 --use-rdk-ui --enable-rdk-voice --playready --widevine --amazon-plugin --enable-fireboltcompliance --rdk-starboard --b12remote
# we skip --enable-rdk-voice --playready --widevine --amazon-plugin 

# build including playready/widevine
#source meta-rdk-aml/set-env.sh mesonsc2-5.4-lib32-ah212 --use-rdk-ui --playready --widevine --enable-fireboltcompliance --rdk-starboard --b12remote

# build without playready/widevine
source meta-rdk-aml/set-env.sh mesonsc2-5.4-lib32-ah212 --use-rdk-ui --enable-fireboltcompliance --rdk-starboard --b12remote

if ! grep -q meta-rdk-cobalt conf/bblayers.conf; then
  echo 'BBLAYERS =+ "\${RDKROOT}/meta-rdk-cobalt"' >> conf/bblayers.conf
fi

echo 'DISTRO_FEATURES_append = " rialto"' >> conf/local.conf

echo "bitbake -k lib32-rdk-generic-mediaclient-image"
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd ah212$TARGET_DIR_SUFFIX; source _build.sh"
