#!/bin/bash
#
# Script to build cobalt appframework with wayland-egl support on RDK-V
#
# Usage example:
#  $ ./rpi-cobalt.sh -d <dirname>    # <dirname> - folder for workspace
#  $ cd <dirname>; ./_build.sh
#  $ ./fetch-rdkv-opencdm.sh -d opencdm-builddir && ./opencdm-builddir/_build.sh
#
# One line command to build cobalt
# $ ./rpi-cobalt.sh -d cobalt-wayland; cd cobalt-wayland; ./_build.sh
#

DIR=cobalt-wayland
BRANCH=morty

while getopts "d:b:h" opt
do
  case "$opt" in
    d) DIR=$OPTARG;;
    b) BRANCH=$OPTARG;;
    h) echo "usage ./rpi-cobalt.sh -d <dirname> -b <branch>"
       echo "<-d> destination dir name"
       echo "<-b> branch (morty/rdk-next)"
       echo "run ./rpi-cobalt.sh to proceed with default directory and branch name"
       exit 0;;
  esac
done

mkdir -p ${DIR}
pushd ${DIR}

#Initializing repo
repo init -u https://code.rdkcentral.com/r/manifests -b ${BRANCH} -m rdkv-nosrc.xml
repo sync -j16 --no-clone-bundle --no-tags

(cd meta-raspberrypi; git clone https://github.com/stagingrdkm/meta-stagingrdkm.git recipes-extended)

## Remove lg recipes from meta-reaspberrypi as it depends on LGI specific classes
rm -rf meta-raspberrypi/recipes-extended/lg

cat <<- 'EOF' >> meta-cmf-raspberrypi/recipes-core/images/rdk-generic-hybrid-refapp-image.bbappend
IMAGE_INSTALL_append += " \
    cobalt \
"
EOF
popd

pushd ${DIR}

cat << 'EOF' > _build.sh
#!/bin/bash
# execute it to run a build:
#   ./_bash.sh
# or source it
#   . ./_bash.sh
export MACHINE="raspberrypirdkhybrefapp"
source meta-cmf-raspberrypi/setup-environment
[ "$0" = "$BASH_SOURCE" ] && time bitbake rdk-generic-hybrid-refapp-image || echo 'run: bitbake rdk-generic-hybrid-refapp-image # or any other command'
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

