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

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b dunfell -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j12

## from https://code.rdkcentral.com/r/plugins/gitiles/collaboration/soc/amlogic/aml-accel-manifests/+/refs/heads/rdk-next/rdk-firebolt-dunfell-ref-sc2-k54-202109.xml
checkout_repo https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers meta-amlogic be293a67d35973fa6ca0e7cb20857db7098db3ea
checkout_repo https://code.rdkcentral.com/r/collaboration/soc/amlogic/yocto_oe/layers meta-rdk-bsp-amlogic 5c16b76fab157709843d033c8cfbb96556ea30c6
checkout_repo https://git.yoctoproject.org/git meta-security 93232ae6d52b0d1968aa0ce69fa745e85e3bbc6b

# Skyworth
# tip of rdk-next on 19-10-2021
checkout_repo "ssh://dev.caldero.com:29418" "meta-rdk-skyworth-hx4x" c33e765d26f8b554dac6bb76632b948b4c9be130
# tip of sc2-rdkservices on 19-10-2021
checkout_repo "https://code.rdkcentral.com/r/collaboration/oem/skyworth/yocto_oe/layers" "meta-rdk-oem-skyworth-aml905X2" 8344d8eb4a29dec8bed62d8116e63cea68521877

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

declare -x MACHINE="mesonsc2-lib32-hp44h-rdk"
. meta-cmf-video-reference-next/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd hp44h_reference_next$TARGET_DIR_SUFFIX; source _build.sh"
