#!/bin/bash -e
#
# Script to build RDK-V with opecdm and WPE from Metrological
#
# Author: Damian Wrobel <dwrobel.contractor@libertyglobal.com>
#
# Usage example:
#  $ ./fetch-rdkv-opencdm.sh -d <dirname>               # <dirname> - where put sources
#  $ ./<dirname>/_build.sh                              # to build sources
#  or
#  $ ./fetch-rdkv-opencdm.sh -d <dirname>               # <dirname> - where put sources
#  $ source ./<dirname>/_build.sh                       # to setup the environment
#  $ bitbake rdk-generic-mediaclient-wpe-opencdm-image  # to build the image
#
# Build the image for raspberry-pi using one-liner command:
#  $ ./fetch-rdkv-opencdm.sh -d opencdm-builddir && ./opencdm-builddir/_build.sh
#
# Using WPE:
# 1) To instruct WPE to show some URL page, please access the following URL from the PC:
#    http://<ip-address-of-your-raspberry-pi>:8800/Service/Controller/UI
# 2) Go to 'WebKitBrowser' list entry and set in the 'Custom URL' the following URL:
#    https://yt-dash-mse-test.commondatastorage.googleapis.com/unit-tests/2017.html?tests=6,7&command=run&test_type=encryptedmedia-test
# 3) press 'SET' button
#

BRANCH=morty
DIR=${BRANCH}
MANIFEST=rdkv-nosrc
PATCH=1
DOWNLOADS=$PWD/downloads

while getopts "D:hb:m:d:p" arg; do
  case $arg in
    h)
      echo "Usage: fetch-sources.sh -b <morty|master> -m <rdkv-raspberrypi|rdkv-nosrc|emulator> -d <destdir default=branch name"
      echo "-b <branch-name>"
      echo "-m <manifest-name>"
      echo "-d <directory-name>"
      echo "-p don't apply cherry-picks"
      echo "Defaults are:"
      echo "    repo init -u https://code.rdkcentral.com/r/manifests -b ${BRANCH} -m ${MANIFEST}.xml # into "${DIR}" directory and using ${DOWNLOADS} as a downloads directory"
      echo ""
      exit 0
      ;;
    b)
      BRANCH=$OPTARG
      ;;
    m)
      MANIFEST=$OPTARG
      ;;
    d)
      DIR=$OPTARG
      ;;
    p)
      PATCH=0
      ;;
    D)
      DOWNLOADS=$OPTARG
      ;;
  esac
done

echo "Using branch=${BRANCH} machine=${MANIFEST} directory=${DIR} patch=${PATCH} downloads=${DOWNLOADS}"
mkdir -p ${DIR}

pushd ${DIR}
    repo init -u https://code.rdkcentral.com/r/manifests -b ${BRANCH} -m ${MANIFEST}.xml
    repo sync -j16 --no-clone-bundle --no-tags

    if [ $MANIFEST == "rdkv-nosrc" ]; then
      mkdir -p rdk/components/generic
      (cd rdk/components/generic; git clone https://code.rdkcentral.com/r/rdk/components/generic/appmanager)
    fi

    if [ $PATCH == 1 ]; then
      # https://github.com/WebPlatformForEmbedded/meta-wpe/commit/279046aaac264d5125fc008b966016a8384c6c03
      (cd meta-wpe; git checkout 279046aaac264d5125fc008b966016a8384c6c03)

      (cd meta-cmf-raspberrypi; git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi refs/changes/01/21401/1 && git cherry-pick FETCH_HEAD)
      (cd meta-cmf-raspberrypi; git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi refs/changes/97/21397/1 && git cherry-pick FETCH_HEAD)
      (cd meta-cmf-raspberrypi; git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi refs/changes/96/21396/1 && git cherry-pick FETCH_HEAD)
      (cd meta-cmf-raspberrypi; git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi refs/changes/90/21390/1 && git cherry-pick FETCH_HEAD)
      (cd meta-cmf-raspberrypi; git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi refs/changes/91/21391/2 && git cherry-pick FETCH_HEAD)
      (cd meta-cmf-raspberrypi; git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi refs/changes/83/21383/2 && git cherry-pick FETCH_HEAD)
      (cd meta-cmf-raspberrypi; git fetch https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-raspberrypi refs/changes/00/21400/2 && git cherry-pick FETCH_HEAD)

      # remove libprovision & cppsdk dependencies
      cat <<- 'EOF' > meta-metrological/recipes-drm/playready/playready_git.bbappend
	DEPENDS_remove  = "cppsdk libprovision"
	RDEPENDS_${PN}_remove = "libprovision"
	PACKAGECONFIG[provisioning] = "-DPLAYREADY_USE_PROVISION=OFF,-DPLAYREADY_USE_PROVISION=OFF,,"
EOF
    # Override port configs for Controller UI and Webserver
      cat <<- 'EOF' >> meta-cmf-raspberrypi/recipes-wpe/wpeframework/wpeframework-plugins_git.bbappend
	WPEFRAMEWORK_PLUGIN_WEBSERVER_PORT = "8008"
	WEBKITBROWSER_STARTURL = "http://localhost:8008/index.html"

EOF
      cat <<- 'EOF' > meta-cmf-raspberrypi/recipes-wpe/wpeframework/wpeframework_git.bbappend
	WPEFRAMEWORK_CONFIG_PORT = "8800"
	DISPLAY_NAME = "WPE"
	EXTRA_OECMAKE_append = " \
	 -DWPEFRAMEWORK_PORT=${WPEFRAMEWORK_CONFIG_PORT} \
	"

	do_install_append() {
	    if ${@bb.utils.contains("DISTRO_FEATURES", "systemd", "true", "false", d)}
	    then
	        sed -i 's/WAYLAND_DISPLAY=wayland-0/WAYLAND_DISPLAY=${DISPLAY_NAME}/g'  ${D}${systemd_unitdir}/system/wpeframework.service
	    fi
	}
EOF
      cat <<- 'EOF' >> meta-cmf-raspberrypi/recipes-core/images/rdk-generic-mediaclient-wpe-opencdm-image.bb
	ROOTFS_POSTPROCESS_COMMAND += "disable_systemd_services; "

	disable_systemd_services() {
	        if [ -d ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/multi-user.target.wants/ ]; then
	                rm -f ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/multi-user.target.wants/appmanager.service;

	        fi
	}
EOF
    fi

popd


pushd ${DIR}

mkdir -p ${DOWNLOADS}
ln -sf ${DOWNLOADS} downloads

cat << 'EOF' > _build.sh
#!/bin/bash
# execute it to run a build:
#   ./_bash.sh
# or source it
#   . ./_bash.sh
pushd $(cd `dirname $0` && pwd)
export MACHINE="raspberrypi-rdk-mc-wpe-opencdm"
# if there is sstate-cache directory - let's link to it
if [ -d ../sstate-cache ]; then
    ln -sf ../sstate-cache
fi
source meta-cmf-raspberrypi/setup-environment
echo >>conf/auto.conf 'PACKAGE_CLASSES = "package_rpm"'
[ "$0" = "$BASH_SOURCE" ] && time bitbake rdk-generic-mediaclient-wpe-opencdm-image || echo 'run: bitbake rdk-generic-mediaclient-wpe-opencdm-image # or any other command'
EOF

chmod u+x _build.sh
popd

cat << EOF
To run the build execute:
    cd ${DIR}
then
  ./_build.sh
or
  . ./_build.sh
EOF
