#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi4_mediaclient_nosrc_dunfell
mkdir rpi4_mediaclient_nosrc_dunfell
cd rpi4_mediaclient_nosrc_dunfell

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b dunfell -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable
MACHINE=raspberrypi4-64-rdk-android-mc source meta-cmf-raspberrypi/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi4_mediaclient_nosrc_dunfell; source _build.sh"
echo "BUILD: bitbake lib32-rdk-generic-mediaclient-wpe-image"
