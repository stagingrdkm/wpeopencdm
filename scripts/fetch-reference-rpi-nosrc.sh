#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_nosrc
mkdir rpi_reference_nosrc
cd rpi_reference_nosrc

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b rdk-next -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
## RDKCMF-8631 Add ocdm and playready packageconfigs for aamp
(cd meta-rdk-video; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk-video" refs/changes/94/40594/1 && git cherry-pick FETCH_HEAD)
## RDKCMF-8631 Enable ocdm and playready packagecfgs for aamp in reference.inc
(cd meta-cmf-video-restricted; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/39/40639/1 && git cherry-pick FETCH_HEAD)
## RDKCMF-8640 Enable gold linker as default
(cd meta-rdk; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-rdk" refs/changes/87/38887/2 && git cherry-pick FETCH_HEAD)
## RDKCMF-8631 Reference image fixes
(cd meta-cmf-video-restricted; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/55/40755/2 && git cherry-pick FETCH_HEAD)
## RDKCMF-8631 Support RDK_ENABLE_REFERENCE_IMAGE to enable reference image features
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/67/40867/1 && git cherry-pick FETCH_HEAD)

## RDKCMF-8631 Fix aamp not playing video on RPI
mkdir -p rdk/components/generic
cd rdk/components/generic
git clone "https://code.rdkcentral.com/r/rdk/components/generic/aamp"
cd -
(cd rdk/components/generic/aamp; git fetch "https://code.rdkcentral.com/r/rdk/components/generic/aamp" refs/changes/39/40439/1 && git cherry-pick FETCH_HEAD)

## keep network management by systemd, we don't include wpeframework network plugin
rm -f meta-wpe/recipes-core/systemd/systemd_%.bbappend

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
declare -x RDK_ENABLE_REFERENCE_IMAGE="y"
. meta-cmf-raspberrypi/setup-environment

echo "PS: use aamp-cli to test some streams (make sure to export AAMP_ENABLE_WESTEROS_SINK=1) :"
echo "  CLEAR: http://amssamples.streaming.mediaservices.windows.net/683f7e47-bd83-4427-b0a3-26a6c4547782/BigBuckBunny.ism/manifest(format=mpd-time-csf)"
echo RUN FOLLOWING TO BUILD: bitbake rdk-generic-reference-image
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_nosrc; source _build.sh"
