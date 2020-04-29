#!/bin/bash
set -x
set -e

######### Build setup and repo sync
rm -rf rpi_reference_nosrc
mkdir rpi_reference_nosrc
cd rpi_reference_nosrc

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b rdk-next -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
## Create rdk-generic-reference-image
(cd meta-cmf-video-restricted;  git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/34/36834/4 && git cherry-pick FETCH_HEAD)
## Add new machine raspberrypi-rdk-hybrid-generic
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/47/37547/2 && git cherry-pick FETCH_HEAD)
## add refApp OVERRIDE check to externalsrc
(cd meta-cmf; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf" refs/changes/25/37525/1 && git cherry-pick FETCH_HEAD)
## remove userland DEPENDS
(cd meta-cmf; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf" refs/changes/42/37942/1 && git cherry-pick FETCH_HEAD)

# OCDM plugins added by setting RDK_WITH_OPENCDM="y" before setup later in script
# adding streamer manually
echo 'PACKAGECONFIG += "streamer"' >> meta-wpe/recipes-wpe/wpeframework/wpeframework-plugins_git.bb 

############# AAMP with OCDM #########
## get latest developments of aamp
mkdir -p rdk/components/generic
cd rdk/components/generic
git clone "https://code.rdkcentral.com/r/rdk/components/generic/aamp"
git clone "https://code.rdkcentral.com/r/rdk/components/generic/gst-plugins-rdk-aamp"
cd -
(cd rdk/components/generic/aamp; git checkout dev_sprint)
(cd rdk/components/generic/gst-plugins-rdk-aamp; git checkout dev_sprint)

## config for aamp
cat <<EOF >> meta-cmf-raspberrypi/recipes-extended/aamp/aamp_git.bbappend
EXTRA_OECMAKE += " -DCMAKE_USE_RDK_PLUGINS=1"
EXTRA_OECMAKE += " -DCMAKE_CDM_DRM=1"
EXTRA_OECMAKE += "\${@bb.utils.contains('DISTRO_FEATURES', 'systemd', ' -DCMAKE_SYSTEMD_JOURNAL=1', '', d)}"
EXTRA_OECMAKE += " -DCMAKE_USE_THUNDER_OCDM_API_0_2=1"
PACKAGECONFIG[opencdm] = "-DCMAKE_USE_OPENCDM=1,-DCMAKE_USE_OPENCDM=0,wpeframework"
PACKAGECONFIG[opencdm_adapter] = "-DCMAKE_USE_OPENCDM_ADAPTER=1,-DCMAKE_USE_OPENCDM_ADAPTER=0,wpeframework"
PACKAGECONFIG_append = " opencdm_adapter"
EOF

cat <<EOF > meta-cmf-raspberrypi/recipes-extended/aamp/gst-plugins-rdk-aamp_git.bbappend
PACKAGECONFIG[opencdm_adapter]  = "-DCMAKE_CDM_DRM=ON -DCMAKE_USE_OPENCDM_ADAPTER=ON,,"
PACKAGECONFIG_append = " opencdm_adapter"
EOF
## fix unneeded and missing dep to sec_api (comcast)
sed -i 's/-locdm -lsec_api"/-locdm"/' rdk/components/generic/gst-plugins-rdk-aamp/CMakeLists.txt
############

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
. meta-cmf-raspberrypi/setup-environment
grep conf/local.conf -e "reference.inc" || echo "require conf/distro/include/reference.inc" >>  conf/local.conf
echo "PS: use aamp-cli to test some streams (make sure to export AAMP_ENABLE_WESTEROS_SINK=1) :"
echo "  CLEAR: http://amssamples.streaming.mediaservices.windows.net/683f7e47-bd83-4427-b0a3-26a6c4547782/BigBuckBunny.ism/manifest(format=mpd-time-csf)"
echo RUN FOLLOWING TO BUILD: bitbake rdk-generic-reference-image
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_nosrc; source _build.sh"
