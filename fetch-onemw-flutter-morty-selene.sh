#!/bin/bash

set -e

# ONEMW source fetcher by Damian Wrobel

# Assumes you have "onemw-gerrit.sh" somewhere in your $PATH


if [ ! -d onemw-manifests ]; then
    git clone ssh://gerrit.onemw.net:29418/onemw-manifests
    (cd onemw-manifests; onemw-gerrit.sh onemw-manifests:42838) # ONEM-12220 ONEM-12398 Adds support for yocto 2.2 (xml)
    (cd onemw-manifests; onemw-gerrit.sh onemw-manifests:45948) # ONEM-10964 Add meta-browser and update meta-clang layer
    (cd onemw-manifests; onemw-gerrit.sh onemw-manifests:57987) # ONEM-10964 selene yocto 2.2
    (cd onemw-manifests; sed -i 's#ssh://gerrit.onemw.net:29418/onemw-manifests#file://${PWD}#' *.conf.*) # Use LG manifests from "this" repository"
    (cd onemw-manifests; sed -i 's/\(repo sync\)/\1 -j$\(getconf _NPROCESSORS_ONLN\)/g'   common_build.sh)  # Speed up repo tool a little bit
    (cd onemw-manifests; sed -i 's/\(repo forall\)/\1 -j$\(getconf _NPROCESSORS_ONLN\)/g' common_build.sh)  # Speed up repo tool a little bit
fi

# this time it's for selene oe22
(cd onemw-manifests; ./selene-build.sh master_oe22)


cherry_picks=(
    meta-lgi-selene:54401    # ONEM-10964 Enable meta-browser & meta-clang repository
    meta-lgi-selene:54402    # ONEM-10964 flutter container
    meta-lgi-selene:57976    # ONEM-10964 yocto 2.2 compatibility
    meta-intelce:57978       # ONEM-12220 yocto 2.2 compatibility
    meta-bsp-intelce:58243   # ONEM-12220 yocto 2.2 compatibility
    meta-lgi-om-common:47525 # ONEM-10964 Tweak gtk+ dependency for chromium
    meta-lgi-om-common:48178 # ONEM-10964 nss: update to 3.28.1
    meta-lgi-om-common:49322 # ONEM-10964 Prevent programs run as root to crash
    meta-lgi-om-common:51256 # ONEM-10964 Enable building glfw shared library
    meta-lgi-om-common:52457 # ONEM-10964 Introduce elfio library
    meta-lgi-om-common:50940 # ONEM-10964 Flutter Engine - beautiful mobile apps (POC)
    meta-lgi-om-common:53346 # ONEM-10964 out-of-the-box flutter-app build
    meta-lgi-om-common:57981 # ONEM-12220 yocto 2.2 compatibility
    meta-lgi-om:53348        # ONEM-10964 corrected dbus scripts to conform with new rdk
    meta-lgi-netflix:53349   # ONEM-10964 removed jsapp part used in netflix scenario
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

SETUP_CONF="meta-lgi-selene/setup-environment-selene"
RDK_BRANCH="rdkv-20180926"

sed -i 's/^\(CONF_RDK_VERSION\).*/\1="'${RDK_BRANCH}'"/g' ${SETUP_CONF}*.conf
sed -i 's/^\(CONF_RDK_YOCTO_VERSION\).*/\1="22"/g' ${SETUP_CONF}*.conf

if [ -n "$(find "downloads" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
    rm -rf downloads
    if [ -d ../../downloads ]; then
        ln -sf ../../downloads
    fi
fi

source ${SETUP_CONF}

add_config 'XZ_COMPRESSION_LEVEL="-e -M 50% -1"' "conf/local.conf"
add_config 'LLVM_TARGETS_TO_BUILD = "X86"' "conf/local.conf"
add_config 'LIBCPLUSPLUS = ""' "conf/local.conf"
add_config 'TARGET_CXXFLAGS_remove_toolchain-clang = " --stdlib=libc++"' "conf/local.conf"
add_config 'TUNE_CCARGS_remove_toolchain-clang = " --rtlib=compiler-rt --unwindlib=libunwind --stdlib=libc++"' "conf/local.conf"
add_config 'DISTRO_FEATURES_append=" flutter "' "conf/local.conf"
add_config '#DISTRO_FEATURES_append=" flutter_aot "' "conf/local.conf"

# Rebuild packages from source
sed -i 's/^\(DISTRO_FEATURES_append=" efl ".*\)/# \1/g' conf/local.conf
sed -i 's/^\(BINPKG_wpe.*\)/# \1/g' conf/local.conf
sed -i 's/^\(BINPKG_ignition.*\)/# \1/g' conf/local.conf

[ "$0" = "$BASH_SOURCE" ] && time bitbake core-image-efl-nodejs || echo 'run bitbake core-image-efl-nodejs # or any other command'
EOF
