#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_next_nosrc
mkdir rpi_reference_next_nosrc
cd rpi_reference_next_nosrc

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b rdk-next -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
## none

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
. ./meta-cmf-video-reference-next/setup-environment

EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_next_nosrc; source _build.sh"
