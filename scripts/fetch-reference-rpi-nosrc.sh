#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_nosrc
mkdir rpi_reference_nosrc
cd rpi_reference_nosrc

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b rdk-next -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks
## none, except for special one later in script (Yajl 2.x)

## re-enable ld-is-gold
sed -i 's/DISTRO_FEATURES_remove_arm = "ld-is-gold"/#DISTRO_FEATURES_remove_arm = "ld-is-gold"/' meta-rdk/conf/distro/include/rdkv.inc

## fix for servicemanager and Yajl 2.x
mkdir -p meta-cmf-video-restricted/recipes-qt/servicemanager/files/
(cd meta-cmf-video-restricted && git fetch "https://code.rdkcentral.com/r/rdk/components/generic/servicemanager" refs/changes/23/38623/1 && git format-patch -1 --stdout FETCH_HEAD > recipes-qt/servicemanager/files/0001-yajl-2.patch)
cat << EOF > meta-cmf-video-restricted/recipes-qt/servicemanager/servicemanager_git.bbappend
FILESEXTRAPATHS_prepend := "\${THISDIR}/files:"
SRC_URI += "file://0001-yajl-2.patch;patchdir=../.."
EOF

############# AAMP with OCDM #########
mkdir -p rdk/components/generic
cd rdk/components/generic
git clone "https://code.rdkcentral.com/r/rdk/components/generic/gst-plugins-rdk-aamp"
cd -
## fix to avoid linking with sec_api which we don't have
(cd rdk/components/generic/gst-plugins-rdk-aamp; git fetch "https://code.rdkcentral.com/r/rdk/components/generic/gst-plugins-rdk-aamp" refs/changes/68/39468/1 && git cherry-pick FETCH_HEAD)

## config for aamp
cat <<EOF >> meta-cmf-raspberrypi/recipes-extended/aamp/aamp_git.bbappend
EXTRA_OECMAKE += " -DCMAKE_USE_RDK_PLUGINS=1"
EXTRA_OECMAKE += " -DCMAKE_CDM_DRM=1"
EXTRA_OECMAKE += "\${@bb.utils.contains('DISTRO_FEATURES', 'systemd', ' -DCMAKE_SYSTEMD_JOURNAL=1', '', d)}"
EXTRA_OECMAKE += " -DCMAKE_USE_THUNDER_OCDM_API_0_2=1"
PACKAGECONFIG[opencdm] = "-DCMAKE_USE_OPENCDM=1,-DCMAKE_USE_OPENCDM=0,wpeframework"
PACKAGECONFIG[clearkey] = "-DCMAKE_USE_CLEARKEY=1,-DCMAKE_USE_CLEARKEY=0,wpeframework"
PACKAGECONFIG[opencdm_adapter] = "-DCMAKE_USE_OPENCDM_ADAPTER=1,-DCMAKE_USE_OPENCDM_ADAPTER=0,wpeframework"
PACKAGECONFIG_append = " opencdm_adapter clearkey"
EOF
cat <<EOF > meta-cmf-raspberrypi/recipes-extended/aamp/gst-plugins-rdk-aamp_git.bbappend
PACKAGECONFIG[opencdm_adapter]  = "-DCMAKE_CDM_DRM=ON -DCMAKE_USE_OPENCDM_ADAPTER=ON,,"
PACKAGECONFIG_append = " opencdm_adapter"
EOF
############

## keep network management by systemd, we don't include wpeframework network plugin
rm -f meta-wpe/recipes-core/systemd/systemd_%.bbappend

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
. meta-cmf-raspberrypi/setup-environment
grep conf/local.conf -e "reference.inc" || echo "require conf/distro/include/reference.inc" >>  conf/local.conf
echo "PS: use aamp-cli to test some streams (make sure to export AAMP_ENABLE_WESTEROS_SINK=1) :"
echo "  CLEAR: http://amssamples.streaming.mediaservices.windows.net/683f7e47-bd83-4427-b0a3-26a6c4547782/BigBuckBunny.ism/manifest(format=mpd-time-csf)"
echo RUN FOLLOWING TO BUILD: bitbake rdk-generic-reference-image
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_nosrc; source _build.sh"
