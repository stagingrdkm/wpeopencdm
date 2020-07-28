#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_rdks_nosrc
mkdir rpi_reference_rdks_nosrc
cd rpi_reference_rdks_nosrc

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b rdk-next -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
## RDKCMF-8631 Add ocdm and playready packageconfigs for aamp
(cd meta-rdk-video; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-video" refs/changes/94/40594/1 && git cherry-pick FETCH_HEAD)

### switch to rdkservices ###
(cd meta-cmf-video-restricted; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/85/41785/3 && git cherry-pick FETCH_HEAD)
(cd meta-rdk-ext; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-ext" refs/changes/89/41789/3 && git cherry-pick FETCH_HEAD)
(cd meta-rdk-video; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-video" refs/changes/01/41801/3 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/70/41970/1 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/57/42157/1 && git cherry-pick FETCH_HEAD)
###	

## RDKCMF-8631 Fix aamp not playing video on RPI
mkdir -p rdk/components/generic
cd rdk/components/generic
git clone "https://code.rdkcentral.com/r/rdk/components/generic/aamp"
cd -
(cd rdk/components/generic/aamp; git fetch "https://code.rdkcentral.com/r/rdk/components/generic/aamp" refs/changes/39/40439/1 && git cherry-pick FETCH_HEAD)

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
declare -x RDK_ENABLE_REFERENCE_IMAGE="y"
. meta-cmf-raspberrypi/setup-environment

echo "PS: use aamp-cli to test some streams (make sure to export AAMP_ENABLE_WESTEROS_SINK=1) :"
echo "  CLEAR: http://amssamples.streaming.mediaservices.windows.net/683f7e47-bd83-4427-b0a3-26a6c4547782/BigBuckBunny.ism/manifest(format=mpd-time-csf)"
echo RUN FOLLOWING TO BUILD: bitbake rdk-generic-reference-image
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_rdks_nosrc; source _build.sh"
