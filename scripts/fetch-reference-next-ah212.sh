#!/bin/bash
set -e
TARGET_DIR_SUFFIX=""
 
######### Build setup and repo sync
rm -rf ah212_reference_next$TARGET_DIR_SUFFIX
mkdir ah212_reference_next$TARGET_DIR_SUFFIX
cd ah212_reference_next$TARGET_DIR_SUFFIX

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

## take newest sources for reference image
checkout_repo https://code.rdkcentral.com/r/a/components/generic/rdk-oe meta-cmf-video-reference master
checkout_repo https://code.rdkcentral.com/r/a/components/generic/rdk-oe meta-cmf-video-reference-next master

## avoid removal of clearkey DISTRO feature
sed -i 's#DISTRO_FEATURES_remove = " compositor clearkey"#DISTRO_FEATURES_remove = "compositor"#' meta-rdk-bsp-amlogic/conf/machine/include/amlogic*.inc

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

declare -x MACHINE="mesonsc2-5.4-lib32-ah212"
. meta-cmf-video-reference-next/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd ah212_reference_next$TARGET_DIR_SUFFIX; source _build.sh"
