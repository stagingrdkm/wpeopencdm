#!/bin/bash

set -e

# ONEMW flutter source fetcher and build script by Damian Wrobel
#
# Author: Damian Wrobel <dwrobel@ertelnet.rybnik.pl>
# Version: v0.3

# Assumes you have "onemw-gerrit.sh" somewhere in your $PATH


git clone ssh://gerrit.onemw.net:29418/onemw-manifests
(cd onemw-manifests; onemw-gerrit.sh onemw-manifests:45948) # ONEM-10964 Add meta-browser and update meta-clang layer
(cd onemw-manifests; sed -i 's#ssh://gerrit.onemw.net:29418/onemw-manifests#file://${PWD}#' *.conf.*) # Use LG manifests from "this" repository"
(cd onemw-manifests; sed -i 's/\(repo sync\)/\1 -j$\(getconf _NPROCESSORS_ONLN\)/g'   common_build.sh)  # Speed up repo tool a little bit
(cd onemw-manifests; sed -i 's/\(repo forall\)/\1 -j$\(getconf _NPROCESSORS_ONLN\)/g' common_build.sh)  # Speed up repo tool a little bit

# this time it's for EOS 18.3
(cd onemw-manifests; ./eos-efl-demo-build.sh usr18.3_oe22)

cherry_picks=(
    meta-lgi-eos:45946       # ONEM-10964 Enable meta-browser & meta-clang repository
    meta-lgi-om-common:47525 # ONEM-10964 Tweak gtk+ dependency for chromium
    meta-lgi-om-common:48178 # ONEM-10964 nss: update to 3.28.1
    meta-lgi-om-common:49322 # ONEM-10964 Prevent programs run as root to crash
    meta-lgi-om-common:51256 # ONEM-10964 Enable building glfw shared library
    meta-lgi-om-common:50940 # ONEM-10964 Flutter Engine - beautiful mobile apps (POC)
)

LOG=$PWD/cherry-pick.log
rm -f $LOG

for i in ${cherry_picks[@]}; do
  IFS=: read -a args <<< $i
  repo=${args[0]} # parse repo name
  if [ "$repo" = "onemw-src" ]; then # special case for onemw-src location
    repo="$repo/onemw-src"
  fi
  (cd onemw/$repo; onemw-gerrit.sh $i || echo "Failed to apply: $i" >> $LOG)
done

cat << 'EOF' > onemw/_build.sh
#!/bin/bash

# source it by using:
#   . ./_bash.sh

[ -f /opt/rh/devtoolset-6/enable ] && source /opt/rh/devtoolset-6/enable

SETUP_CONF=meta-lgi-eos/setup-environment-eos

sed -i 's/^\(CONF_BCM_URSR_VERSION\).*/\1="18_3"/g' ${SETUP_CONF}.conf
sed -i 's/^\(CONF_RDK_YOCTO_VERSION\).*/\1="22"/g' ${SETUP_CONF}.conf

if [ -n "$(find "downloads" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

source ${SETUP_CONF}

cat << 'EOD' >> conf/local.conf

XZ_COMPRESSION_LEVEL="-e -M 50% -1"

LLVM_TARGETS_TO_BUILD = "ARM"

LIBCPLUSPLUS = ""
TARGET_CXXFLAGS_remove_toolchain-clang = " --stdlib=libc++"
TUNE_CCARGS_remove_toolchain-clang = " --rtlib=compiler-rt --unwindlib=libunwind --stdlib=libc++"

IMAGE_INSTALL_append = " flutter-launcher"
IMAGE_INSTALL_append = " flutter-launcher-glfw"
IMAGE_INSTALL_append = " flutter-launcher-wayland"

IMAGE_INSTALL_append = " flutter-examples-dataviz"
IMAGE_INSTALL_append = " flutter-examples-filipino-cuisine"
IMAGE_INSTALL_append = " flutter-examples-gallery"
IMAGE_INSTALL_append = " flutter-examples-slide-puzzle"

EOD

# Rebuild packages from source
sed -i 's/^\(BINPKG_wpe.*\)/# \1/g' conf/local.conf
sed -i 's/^\(BINPKG_ignition.*\)/# \1/g' conf/local.conf

[ "$0" = "$BASH_SOURCE" ] && time bitbake core-image-efl-nodejs || echo 'run bitbake core-image-efl-nodejs # or any other command'
EOF

[ -f $LOG ] && (cat $LOG; exit 2)
