#!/bin/bash
set -e
TARGET_DIR_SUFFIX=""
 
######### Build setup and repo sync
rm -rf hp44h_reference_next$TARGET_DIR_SUFFIX
mkdir hp44h_reference_next$TARGET_DIR_SUFFIX
cd hp44h_reference_next$TARGET_DIR_SUFFIX

checkout_repo() {
  if [ ! -d $2 ] ; then
     git clone $1/$2
  fi
  cd $2
  git checkout $3
  cd -
}

repo init -u https://code.rdkcentral.com/r/collaboration/soc/amlogic/aml-accel-manifests -b rdk-next -m rdk-firebolt-dunfell-ref-sc2-k54.xml
repo sync --no-clone-bundle -j12

## clone repos not yet in manifest
########## Skyworth sources ######################################
checkout_repo "ssh://dev.caldero.com:29418" "meta-rdk-skyworth-hx4x" rdk-next
checkout_repo "https://code.rdkcentral.com/r/collaboration/oem/skyworth/yocto_oe/layers" "meta-rdk-oem-skyworth-aml905X2" sc2-rdkservices

## avoid removal of clearkey DISTRO feature
sed -i 's#DISTRO_FEATURES_remove = " compositor clearkey"#DISTRO_FEATURES_remove = "compositor"#' meta-rdk-bsp-amlogic/conf/machine/include/amlogic_32b.inc

cd meta-cmf-video-reference
git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference refs/changes/08/60508/2 && git cherry-pick FETCH_HEAD
cd -
cd meta-cmf-video-reference-next
git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference-next refs/changes/75/60675/1 && git cherry-pick FETCH_HEAD
cd -

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

declare -x MACHINE="mesonsc2-lib32-hp44h-rdk"
. meta-cmf-video-reference-next/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd hp44h_reference_next$TARGET_DIR_SUFFIX; source _build.sh"
