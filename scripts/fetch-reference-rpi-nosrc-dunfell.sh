#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_nosrc_dunfell
mkdir rpi_reference_nosrc_dunfell
cd rpi_reference_nosrc_dunfell

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b dunfell -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
(cd meta-cmf-video-reference && git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-reference refs/changes/87/54287/3 && git cherry-pick FETCH_HEAD)

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"

[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

. meta-cmf-video-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_nosrc_dunfell; source _build.sh"
