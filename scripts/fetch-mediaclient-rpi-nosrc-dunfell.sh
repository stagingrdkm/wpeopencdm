#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_mediaclient_nosrc_dunfell
mkdir rpi_mediaclient_nosrc_dunfell
cd rpi_mediaclient_nosrc_dunfell

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b dunfell -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

cat <<EOF >> _build.sh

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

MACHINE=raspberrypi-rdk-mc source meta-cmf-raspberrypi/setup-environment

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_mediaclient_nosrc_dunfell; source _build.sh"
echo "BUILD: bitbake rdk-generic-mediaclient-wpe-image"
