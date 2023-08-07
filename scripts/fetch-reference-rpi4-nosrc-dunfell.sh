#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi4_reference_nosrc_dunfell
mkdir rpi4_reference_nosrc_dunfell
cd rpi4_reference_nosrc_dunfell

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b dunfell -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi4-64-rdk-android-mc"
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable
. meta-cmf-video-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi4_reference_nosrc_dunfell; source _build.sh"
