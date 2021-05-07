#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_next_nosrc_dunfell
mkdir rpi_reference_next_nosrc_dunfell
cd rpi_reference_next_nosrc_dunfell

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b dunfell -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
## none

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. ./meta-cmf-video-reference-next/setup-environment

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_next_nosrc_dunfell; source _build.sh"
