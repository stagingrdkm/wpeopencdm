#!/bin/bash
set -e
TARGET_DIR_SUFFIX=""
 
######### Build setup and repo sync
rm -rf hp44h_reference_next$TARGET_DIR_SUFFIX
mkdir hp44h_reference_next$TARGET_DIR_SUFFIX
cd hp44h_reference_next$TARGET_DIR_SUFFIX

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b rdk-next -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

## clone repos not yet in manifest

git clone "ssh://stefan.verkoyen@dev.caldero.com:29418/meta-rdk-skyworth-hx4x"
cd meta-rdk-skyworth-hx4x
git checkout rdk-next
cd -

git clone "https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers/meta-rdk-aml"
cd meta-rdk-aml
git checkout rdk-next
cd -

git clone "https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers/meta-rdk-bsp-amlogic"
cd meta-rdk-bsp-amlogic
git checkout amlogic-ref-rdkservices
cd -

git clone "https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers/meta-amlogic"
cd meta-amlogic
git checkout amlogic-ref-rdkservices
cd -

git clone "https://code.rdkcentral.com/r/collaboration/oem/skyworth/yocto_oe/layers/meta-rdk-oem-skyworth-aml905X2"
cd meta-rdk-oem-skyworth-aml905X2
git checkout sc2-rdkservices
cd -

## avoid removal of clearkey DISTRO feature
sed -i 's#DISTRO_FEATURES_remove = " compositor clearkey"#DISTRO_FEATURES_remove = "compositor"#' meta-rdk-bsp-amlogic/conf/machine/include/amlogic_32b.inc

##### cherry picks
cd meta-amlogic
git fetch https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers/meta-amlogic refs/changes/39/57939/1 && git cherry-pick FETCH_HEAD
cd -
cd meta-cmf-video-reference
git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference refs/changes/24/58424/3 && git cherry-pick FETCH_HEAD
cd -

cat <<EOF >> _build.sh
declare -x MACHINE="mesonsc2-hp44h-rdk"
. meta-cmf-video-reference-next/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd hp44h_reference_next$TARGET_DIR_SUFFIX; source _build.sh"
