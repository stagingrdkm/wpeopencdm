#!/bin/bash
set -e
TARGET_DIR_SUFFIX=""
 
######### Build setup and repo sync
rm -rf ah212_reference$TARGET_DIR_SUFFIX
mkdir ah212_reference$TARGET_DIR_SUFFIX
cd ah212_reference$TARGET_DIR_SUFFIX

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

## Fix some manifest versions, we need newer sources
checkout_repo https://code.rdkcentral.com/r/a/components/generic/rdk-oe meta-cmf-video-reference ee0cdb748d1f2c29f951e54bba31988a8cc4c889

## avoid removal of clearkey DISTRO feature
sed -i 's#DISTRO_FEATURES_remove = " compositor clearkey"#DISTRO_FEATURES_remove = "compositor"#' meta-rdk-bsp-amlogic/conf/machine/include/amlogic*.inc

## cherry picks
cd meta-cmf-video-reference
git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference refs/changes/78/61078/2 && git cherry-pick FETCH_HEAD
cd -

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

declare -x MACHINE="mesonsc2-5.4-lib32-ah212"
. meta-cmf-video-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd ah212_reference$TARGET_DIR_SUFFIX; source _build.sh"
