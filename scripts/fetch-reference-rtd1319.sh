#!/bin/bash
set -e
TARGET_DIR_SUFFIX=""
 
######### Build setup and repo sync
rm -rf rtd1319_reference$TARGET_DIR_SUFFIX
mkdir rtd1319_reference$TARGET_DIR_SUFFIX
cd rtd1319_reference$TARGET_DIR_SUFFIX

repo init --no-clone-bundle -u https://code.rdkcentral.com/r/manifests -b dunfell -m rdkv-nosrc.xml
repo sync --no-clone-bundle -j12

## clone meta-rdk-soc-realtek but only shallow because connection sometimes very slow
## do regular clone if you want to inspect other branches and history
git clone ssh://gitsrv.realtek.com:29418/git/DHC_SDK/cmf/rdk/yocto_oe/layers/meta-rdk-soc-realtek --branch release/common/rdk-next-dunfell --depth 1 --single-branch meta-rdk-soc-realtek

cat <<EOF >> _build.sh
[ -f /opt/rh/devtoolset-7/enable ] && source /opt/rh/devtoolset-7/enable

declare -x MACHINE="mediabox"
source meta-cmf-video-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rtd1319_reference$TARGET_DIR_SUFFIX; source _build.sh"
