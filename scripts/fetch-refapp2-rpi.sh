#!/bin/bash
set -x
set -e

######### Build setup and repo sync
rm -rf rpi_refapp2
mkdir rpi_refapp2
cd rpi_refapp2

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/rdk/yocto_oe/manifests/bcm-accel-manifests -b rdk-next -m default_collaboration.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
(cd meta-cmf-video-restricted;  git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/34/36834/2 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/47/37547/1 && git cherry-pick FETCH_HEAD)
(cd meta-cmf; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf" refs/changes/25/37525/1 && git cherry-pick FETCH_HEAD)

# OCDM plugins added by setting RDK_WITH_OPENCDM="y" before setup later in script
# adding streamer manually
echo 'PACKAGECONFIG += "streamer"' >> meta-wpe/recipes-wpe/wpeframework/wpeframework-plugins_git.bb 

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
. meta-cmf-raspberrypi/setup-environment
grep conf/local.conf -e "refapp2.inc" || echo "require conf/distro/include/refapp2.inc" >>  conf/local.conf
echo "PS: use aamp-cli to test some streams (make sure to export AAMP_ENABLE_WESTEROS_SINK=1) :"
echo "  CLEAR: http://amssamples.streaming.mediaservices.windows.net/683f7e47-bd83-4427-b0a3-26a6c4547782/BigBuckBunny.ism/manifest(format=mpd-time-csf)"
echo RUN FOLLOWING TO BUILD: bitbake rdk-generic-refapp2-image
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_refapp2; source _build.sh"
