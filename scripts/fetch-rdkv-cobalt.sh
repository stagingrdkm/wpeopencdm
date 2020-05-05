#!/bin/bash -e
#
# Script to build refapp image with cobalt framework and refapp2 for RDK-V
#
# Author: Damian Wrobel <dwrobel.contractor@libertyglobal.com>
#
# Version: 0.3
#
# Usage example:
#  $ ./fetch-rdkv-cobalt.sh -d <dirname>                # <dirname> - where put sources
#  $ ./<dirname>/_build.sh                              # to build sources
#  or
#  $ ./fetch-rdkv-cobalt.sh -d <dirname>                # <dirname> - where put sources
#  $ cd <dirname>                                       # change dir. where _build.sh is located
#  $ source ./_build.sh                                 # to setup the environment
#  $ bitbake rdk-generic-hybrid-refapp-image            # to build the image
#
# Build the image for raspberry-pi using one-liner command:
#  $ ./fetch-rdkv-cobalt.sh -d builddir && (cd ./builddir; ./_build.sh)
#

BRANCH=rdk-next
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

    # Temporary cherry-picks (not merged upstream) to build the image
    if [ $PATCH == 1 ]; then
	echo Apply patches...
        # RDKCMF-8585 Add refapp2 (Lightning based)
        (cd meta-cmf-video-restricted; git fetch "https://code.rdkcentral.com/r/components/generic/rdk-oe/meta-cmf-video-restricted" refs/changes/30/38330/1 && git cherry-pick FETCH_HEAD)
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

export MACHINE="raspberrypirdkhybrefapp"

# if there is sstate-cache directory - let's link to it
if [ -d ../sstate-cache ]; then
    ln -sf ../sstate-cache
fi

source meta-cmf-raspberrypi/setup-environment

echo >>conf/auto.conf 'PACKAGE_CLASSES = "package_rpm"'
echo >>conf/auto.conf 'INCOMPATIBLE_LICENSE_pn-gdb = ""'
echo >>conf/auto.conf 'PACKAGECONFIG_remove_pn-gdb = "readline"'
echo >>conf/auto.conf 'IMAGE_INSTALL_append = " gdb strace tcpdump nfs-utils"'


[ "$0" = "$BASH_SOURCE" ] && time bitbake rdk-generic-hybrid-refapp-image || echo 'run bitbake rdk-generic-hybrid-refapp-image # or any other command'
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
