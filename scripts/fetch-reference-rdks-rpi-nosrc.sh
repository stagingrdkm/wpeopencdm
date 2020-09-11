#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_rdks_nosrc
mkdir rpi_reference_rdks_nosrc
cd rpi_reference_rdks_nosrc

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b rdk-next -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks

## lightning refapp2
(cd meta-cmf-video-restricted; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/30/38330/27 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-video-restricted; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/19/44319/2 && git cherry-pick FETCH_HEAD)
(cd meta-rdk-ext; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-ext" refs/changes/80/40980/2 && git cherry-pick FETCH_HEAD)
###

### switch to rdkservices ###

## cherry-pick fails because of above cherry picks
##(cd meta-cmf-video-restricted; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/85/41785/11 && git cherry-pick FETCH_HEAD)
cd meta-cmf-video-restricted
sed -i '/lighttpd/d' conf/distro/include/reference.inc
git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/85/41785/11 && git format-patch -1 --stdout FETCH_HEAD | patch -p1
echo 'BBMASK .= "|meta-brcm-refboard/recipes-extended/lighttpd"' >> conf/distro/include/reference.inc
cd -
###

(cd meta-rdk-ext; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-ext" refs/changes/89/41789/9 && git cherry-pick FETCH_HEAD)
(cd meta-rdk-video; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-video" refs/changes/01/41801/13 && git cherry-pick FETCH_HEAD)
(cd meta-rdk-video; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-video" refs/changes/85/42385/5 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/59/42159/5 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/57/42157/1 && git cherry-pick FETCH_HEAD)
###

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
declare -x RDK_ENABLE_REFERENCE_IMAGE="y"
. meta-cmf-raspberrypi/setup-environment

echo "PS: use aamp-cli to test some streams (make sure to export AAMP_ENABLE_WESTEROS_SINK=1) :"
echo "  CLEAR: http://amssamples.streaming.mediaservices.windows.net/683f7e47-bd83-4427-b0a3-26a6c4547782/BigBuckBunny.ism/manifest(format=mpd-time-csf)"
echo RUN FOLLOWING TO BUILD: bitbake rdk-generic-reference-image
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_rdks_nosrc; source _build.sh"
