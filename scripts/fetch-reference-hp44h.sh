#!/bin/bash
set -e
TARGET_DIR_SUFFIX=""
 
######### Build setup and repo sync
rm -rf hp44h_reference$TARGET_DIR_SUFFIX
mkdir hp44h_reference$TARGET_DIR_SUFFIX
cd hp44h_reference$TARGET_DIR_SUFFIX

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

## Fix some manifest versions, we need newer sources
checkout_repo https://code.rdkcentral.com/r/a/components/generic/rdk-oe meta-cmf-video-reference 73a705405cbb4bce15175d55d9210dddcee980eb

## avoid removal of clearkey DISTRO feature
sed -i 's#DISTRO_FEATURES_remove = " compositor clearkey"#DISTRO_FEATURES_remove = "compositor"#' meta-rdk-bsp-amlogic/conf/machine/include/amlogic*.inc

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

declare -x MACHINE="mesonsc2-lib32-hp44h-rdk"
. meta-cmf-video-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd hp44h_reference$TARGET_DIR_SUFFIX; source _build.sh"
