#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi3_mediaclient_nosrc_rdk6
mkdir rpi3_mediaclient_nosrc_rdk6
cd rpi3_mediaclient_nosrc_rdk6

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b rdk6-main -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable
MACHINE=raspberrypi-rdk-mc source meta-cmf-raspberrypi/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi3_mediaclient_nosrc_rdk6; source _build.sh"
echo "BUILD: bitbake rdk-generic-mediaclient-image"
