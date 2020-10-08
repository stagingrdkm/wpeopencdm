#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_nosrc
mkdir rpi_reference_nosrc
cd rpi_reference_nosrc

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
## none

## temporary fixes
## re-enable network
sed -i '/network/d' meta-cmf-video-reference/conf/distro/include/reference.inc

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
. meta-cmf-video-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_nosrc; source _build.sh"
