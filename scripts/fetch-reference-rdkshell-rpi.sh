#!/bin/bash
set -e

######### Build setup and repo sync
rm -rf rpi_reference_rdkshell
mkdir rpi_reference_rdkshell
cd rpi_reference_rdkshell

repo init -u https://code.rdkcentral.com/r/collaboration/soc/broadcom/manifests -m reference/manifest-next-nosrc.xml
repo sync --no-clone-bundle -j$(getconf _NPROCESSORS_ONLN)

# fetch reference image layer
git clone git@github.com:sverkoye/meta-cmf-reference.git

cat <<EOF >> _build.sh
declare -x MACHINE="raspberrypi-rdk-hybrid-generic"
. meta-cmf-reference/setup-environment
EOF

echo "RUN FOLLOWING TO PREPARE FOR BUILD: cd rpi_reference_rdkshell; source _build.sh"
