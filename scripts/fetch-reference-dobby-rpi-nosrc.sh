#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_dobby_nosrc
mkdir rpi_reference_dobby_nosrc
cd rpi_reference_dobby_nosrc

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

##### cherry picks

### switch to rdkservices ###
(cd meta-cmf-video-restricted; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/85/41785/15 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/59/42159/5 && git cherry-pick FETCH_HEAD)
(cd meta-cmf-raspberrypi; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi" refs/changes/57/42157/2 && git cherry-pick FETCH_HEAD)
###

# take latest recipes from comcast: dobby, crun, wpeframework and tools
mkdir comcast
cd comcast
git clone https://gerrit.teamccp.com/rdk/yocto_oe/layers/meta-rdk-ext
(cd meta-rdk-ext; git checkout 2009_sprint)
git clone https://gerrit.teamccp.com/rdk/yocto_oe/layers/meta-rdk-video
(cd meta-rdk-video; git checkout 2009_sprint)
cd ..
cp -rf comcast/meta-rdk-ext/recipes-containers/dobby meta-rdk-ext/recipes-containers/
cp -rf comcast/meta-rdk-ext/recipes-containers/crun meta-rdk-ext/recipes-containers/
cp -rf comcast/meta-rdk-ext/recipes-core/ctemplate meta-rdk-ext/recipes-core/
cp -rf comcast/meta-rdk-ext/recipes-devtools/jsoncpp meta-rdk-ext/recipes-devtools/
cp -rf comcast/meta-rdk-video/recipes-extended/rdkservices meta-rdk-video/recipes-extended/

##
sed -i 's#rdkcentral/rdkservices.git#sverkoye/rdkservices.git#' meta-rdk-video/recipes-extended/rdkservices/rdkservices_git.bb
echo 'SRCREV = "0fb2cadc16b22832ab1fae31569dfd130b3f04cd"' >>  meta-rdk-video/recipes-extended/rdkservices/rdkservices_git.bb
echo 'PACKAGECONFIG[ocicontainer]  = "-DPLUGIN_OCICONTAINER=ON,-DPLUGIN_OCICONTAINER=OFF,dobby,dobby"' >> meta-rdk-video/recipes-extended/rdkservices/rdkservices_git.bb
echo 'PACKAGECONFIG[dacapplication]  = "-DPLUGIN_DACAPPLICATION=ON,-DPLUGIN_DACAPPLICATION=OFF,,"' >> meta-rdk-video/recipes-extended/rdkservices/rdkservices_git.bb

sed -i '/spark/d' meta-cmf-video-restricted/conf/distro/include/reference.inc
echo 'BBMASK .= "|meta-cmf-video-restricted/recipes-containers/crun"' >> meta-cmf-video-restricted/conf/distro/include/reference.inc
echo 'PACKAGECONFIG_append_pn-rdkservices = " dacapplication"' >> meta-cmf-video-restricted/conf/distro/include/reference.inc
echo 'PACKAGECONFIG_append_pn-rdkservices = " ocicontainer"' >> meta-cmf-video-restricted/conf/distro/include/reference.inc
echo 'PACKAGECONFIG_append_pn-rdkservices = " rdkshell"' >> meta-cmf-video-restricted/conf/distro/include/reference.inc

cat <<EOF >> meta-cmf-video-restricted/recipes-extended/dac/dac_git.bb
do_install_append() {
   sed -i '/wayland/d' \${D}\${INSDIR}/platform/\${DAC_PLATFORM}/files.txt
   sed -i 's/wayland-0/westeros/' \${D}\${INSDIR}/platform/\${DAC_PLATFORM}/env.txt
   sed -i 's#/run#/tmp#' \${D}\${INSDIR}/platform/\${DAC_PLATFORM}/env.txt
}
EOF

sed -i 's/wayland-wpe-0/wayland-0/' meta-cmf-video-restricted/recipes-core/images/rdk-generic-reference-image.bb
sed -i 's/appmanager/dac refapp2/' meta-cmf-video-restricted/recipes-core/images/rdk-generic-reference-image.bb
cat <<EOF >> meta-cmf-video-restricted/recipes-core/images/rdk-generic-reference-image.bb
ROOTFS_POSTPROCESS_COMMAND += "fixes_webkitbrowser; "

fixes_webkitbrowser() {
        if [ -f \${IMAGE_ROOTFS}\${sysconfdir}/WPEFramework/plugins/WebKitBrowser.json ]; then
                sed -i 's/"autostart":false/"autostart":true/' \${IMAGE_ROOTFS}\${sysconfdir}/WPEFramework/plugins/WebKitBrowser.json;
                sed -i 's#"url":"about:blank"#"url":"http://127.0.0.1:50050/refapp2/index.html"#' \${IMAGE_ROOTFS}\${sysconfdir}/WPEFramework/plugins/WebKitBrowser.json;
        fi
}
EOF

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
declare -x RDK_ENABLE_REFERENCE_IMAGE="y"
. meta-cmf-raspberrypi/setup-environment

echo "PS: use aamp-cli to test some streams (make sure to export AAMP_ENABLE_WESTEROS_SINK=1) :"
echo "  CLEAR: http://amssamples.streaming.mediaservices.windows.net/683f7e47-bd83-4427-b0a3-26a6c4547782/BigBuckBunny.ism/manifest(format=mpd-time-csf)"
echo RUN FOLLOWING TO BUILD: bitbake rdk-generic-reference-image
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_dobby_nosrc; source _build.sh"
