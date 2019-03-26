#!/bin/bash -e

# Simple script to build WPEFramework with all dependencies
#
# Tested on Fedora 29 using default Wayland display server
#
# Author: Damian Wrobel <dwrobel.contractor@libertyglobal.com>

export MOPTS="-j$(getconf _NPROCESSORS_ONLN) VERBOSE=1"

export CFLAGS="-g3 -O0"
export CXXFLAGS="-g3 -O0 -Wno-class-memaccess -fno-omit-frame-pointer -DDEBUG"

prefix=$PWD/_install

export PKG_CONFIG_PATH="$prefix/usr/lib/pkgconfig"
export CMOPTS="-DCMAKE_INSTALL_PREFIX:PATH=$prefix/usr/ -DLIB_INSTALL_DIR=$prefix/usr/lib/ -DCMAKE_INSTALL_LIBDIR=$prefix/usr/lib/ -DCMAKE_MODULE_PATH=$prefix/usr/lib/cmake"



# last commit before 1.0.0 version
# git checkout 705103d4d106bc47522d66636fc8327af71e5771
if true; then
# DEPS: dnf install cmake gcc-c++ mesa-libEGL-devel libxkbcommon-devel
echo "compiling libwpe..."
pushd libwpe
mkdir -p build
    pushd build
        cmake ${CMOPTS} ..
        make ${MOPTS} install
    popd
popd
fi

if true; then
echo "compiling WPEBackend-rdk..."

EXTRA_OECMAKE="  -DCMAKE_BUILD_TYPE=Release -DUSE_INPUT_LIBINPUT=OFF -DUSE_INPUT_UDEV=OFF -DUSE_VIRTUAL_KEYBOARD=OFF -DUSE_BACKEND_WAYLAND_EGL=ON -DUSE_INPUT_WAYLAND=ON -DUSE_INPUT_LIBINPUT=OFF"

pushd WPEBackend-rdk
mkdir -p build
    pushd build
        cmake ${CMOPTS} ${EXTRA_OECMAKE} ..
        make ${MOPTS} install
    popd
popd
fi

if true; then
echo "compiling WPEFramework..."

EXTRA_OECMAKE="-D__CMAKE_SYSROOT=/data/dwrobel1/onemw/onemw/oe-builds/svp-c/onemw/build-brcm97449svms-refboard/tmp/sysroots/dcx960-debug      \
-DINSTALL_HEADERS_TO_TARGET=ON     -DEXTERN_EVENTS=\"     Decryption WebSource          Location Time Internet \"     \
-DBUILD_SHARED_LIBS=ON     -DRPC=ON     -DBUILD_REFERENCE=69756f29d38c2b80db7bcf69c2e660f8bf8c010d     -DTREE_REFERENCE=69756f29d38c2b80db7bcf69c2e660f8bf8c010d    \
-DPERSISTENT_PATH=$prefix/home/$(id -un)   -DSYSTEM_PREFIX=OE   -DBLUETOOTH_SUPPORT=OFF -DTEST_CYCLICINSPECTOR=OFF -DBUILD_TYPE=Debug -DCDMI=ON -DTEST_LOADER=OFF -DVIRTUALINPUT=ON \
-DPLUGIN_WEBKITBROWSER=ON -DPLUGIN_WEBSERVER=ON \
-DCDMI_ADAPTER_IMPLEMENTATION=gstreamer"

pushd WPEFramework
mkdir -p build
    pushd build
        cmake ${CMOPTS} ${EXTRA_OECMAKE} ..
        make ${MOPTS} install
    popd
popd
fi

if false; then
# DEPS: dnf install ninja-build bison cairo-devel cmake flex gcc-c++ gnutls-devel gperf gstreamer1-devel gstreamer1-plugins-bad-free-devel gstreamer1-plugins-base-devel harfbuzz-devel \
# libepoxy-devel libicu-devel libjpeg-devel libpng-devel libsoup-devel libwebp-devel libxslt-devel mesa-libEGL-devel mesa-libgbm-devel perl-File-Copy-Recursive perl-JSON-PP perl-Switch \
# python2 ruby rubygems sqlite-devel wayland-devel wayland-protocols-devel woff2-devel
echo "compiling WPEWebKit..."

# disable ENABLE_ACCELERATED_2D_CANVAS=OFF https://lists.fedoraproject.org/archives/list/devel@lists.fedoraproject.org/thread/RKZMG26MKUEM2W74ILCC5RL7A2XMJRFN/
EXTRA_OECMAKE="-DCMAKE_BUILD_TYPE=Release     -DCMAKE_COLOR_MAKEFILE=OFF     -DEXPORT_DEPRECATED_WEBKIT2_C_API=ON     -DBUILD_SHARED_LIBS=ON     -DPORT=WPE     -G Ninja \
-D__CMAKE_C_COMPILER_LAUNCHER=ccache     -D__CMAKE_CXX_COMPILER_LAUNCHER=ccache   -DENABLE_ACCELERATED_2D_CANVAS=OFF -DENABLE_DEVICE_ORIENTATION=ON -DUSE_GSTREAMER_GL=OFF \
-DENABLE_ENCRYPTED_MEDIA=ON -DENABLE_FETCH_API=ON -DENABLE_FULLSCREEN_API=ON -DUSE_FUSION_API_GSTREAMER=OFF -DENABLE_GAMEPAD=ON -DENABLE_GEOLOCATION=OFF \
-DENABLE_INDEXED_DATABASE=ON -DENABLE_LOGS=ON -DENABLE_MEDIA_SOURCE=ON -DENABLE_MEDIA_STATISTICS=ON -DENABLE_NATIVE_AUDIO=OFF -DENABLE_NATIVE_VIDEO=ON \
-DUSE_WPEWEBKIT_PLATFORM_BCM_NEXUS=ON -DUSE_HOLE_PUNCH_GSTREAMER=ON -DUSE_WPEWEBKIT_PLATFORM_BCM_NEXUS_18_3=ON -DENABLE_NOTIFICATIONS=ON -DENABLE_OPENCDM=ON \
-DENABLE_PLAYREADY=ON -DENABLE_SAMPLING_PROFILER=ON -DENABLE_TEXT_SINK=ON -DENABLE_SUBTLE_CRYPTO=ON -DENABLE_VIDEO=ON -DENABLE_VIDEO_TRACK=ON -DENABLE_WEB_AUDIO=ON \
-DENABLE_WEB_CRYPTO=OFF -DUSE_WOFF2=OFF"

pushd WPEWebKit
    mkdir -p build

    pushd build
        echo "Configuring WPEWebkit..."
        cmake ${CMOPTS} ${EXTRA_OECMAKE} ..
        echo "Building WPEWebkit... $PWD"
        ninja -j$(getconf _NPROCESSORS_ONLN) libWPEWebKit.so libWPEWebInspectorResources.so WPEWebProcess WPENetworkProcess WPEStorageProcess WPEWebDriver

        echo "Installing WebKit... $PWD"
	cmake -P cmake_install.cmake

#	cmake -DCOMPONENT=Development -P Source/WebKit/cmake_install.cmake
#	echo "Installing JavaScriptCore... $PWD"
#	cmake -DCOMPONENT=Development -P Source/JavaScriptCore/cmake_install.cmake
    popd
popd
fi


if true; then
echo "compiling WPEFrameworkPlugins..."

EXTRA_OECMAKE=" -D__CMAKE_SYSROOT=/data/dwrobel1/onemw/onemw/oe-builds/svp-c/onemw/build-brcm97449svms-refboard/tmp/sysroots/dcx960-debug      \
-DBUILD_REFERENCE=a24fc1840dcb78c3e7a7aaa05934bd8bb0066266     -DBUILD_SHARED_LIBS=ON   -DPLUGIN_BLUETOOTH=OFF -DPLUGIN_COMPOSITOR=OFF -DCMAKE_BUILD_TYPE=Release \
-DPLUGIN_DEVICEINFO=ON -DPLUGIN_DICTIONARY=ON -DPLUGIN_IOCONNECTOR=OFF -DPLUGIN_LOCATIONSYNC=ON -DPLUGIN_LOCATIONSYNC_URI=http://jsonip.metrological.com/?maf=true \
-DPLUGIN_MONITOR=ON                                  -DPLUGIN_WEBKITBROWSER_MEMORYLIMIT=614400                                  -DPLUGIN_YOUTUBE_MEMORYLIMIT=614400 \
-DPLUGIN_NETFLIX_MEMORYLIMIT=307200                                  -DPLUGIN_NETWORKCONTROL=OFF -D__PLUGIN_OPENCDMI=ON          -DPLUGIN_OPENCDMI_AUTOSTART=false  \
-DPLUGIN_OPENCDMI_OOP=true                                  -DPLUGIN_POWER=OFF -D__PLUGIN_REMOTECONTROL=ON                        -DPLUGIN_REMOTECONTROL_POSTLOOKUP_CALLSIGN= \
-DPLUGIN_REMOTECONTROL_POSTLOOKUP_MAPFILE=                                    -DPLUGIN_REMOTECONTROL_DEVINPUT=ON -DPLUGIN_REMOTECONTROL_IR=OFF -DPLUGIN_SNAPSHOT=OFF \
-DPLUGIN_SYSTEMDCONNECTOR=OFF -DPLUGIN_TIMESYNC=ON -DPLUGIN_TRACECONTROL=ON -DPLUGIN_WEBKITBROWSER_UX=ON -DPLUGIN_COMPOSITOR_VIRTUALINPUT=ON -DPLUGIN_WEBKITBROWSER=ON  \
-DPLUGIN_WEBKITBROWSER_AUTOSTART=\"true\"    -DPLUGIN_WEBKITBROWSER_MEDIADISKCACHE=\"false\"  \
-DPLUGIN_WEBKITBROWSER_MEMORYPRESSURE=\"databaseprocess:50m,networkprocess:100m,webprocess:300m,rpcprocess:50m\"    -DPLUGIN_WEBKITBROWSER_MEMORYPROFILE=\"128m\" \
-DPLUGIN_WEBKITBROWSER_MSEBUFFERS=\"audio:2m,video:15m,text:1m\"    -DPLUGIN_WEBKITBROWSER_STARTURL=\"http://localhost:8080/index.html\"    \
-DPLUGIN_WEBKITBROWSER_USERAGENT=\"Mozilla/5.0 (Macintosh, Intel Mac OS X 10_11_4) AppleWebKit/602.1.28+ (KHTML, like Gecko) Version/9.1 Safari/601.5.17\"   \
-DPLUGIN_WEBKITBROWSER_DISKCACHE=\"0\"    -DPLUGIN_WEBKITBROWSER_XHRCACHE=\"false\"    -DPLUGIN_WEBKITBROWSER_TRANSPARENT=\"false\"    -DPLUGIN_WEBKITBROWSER_THREADEDPAINTING=\"1\" \
-DPLUGIN_WEBPROXY=OFF -DPLUGIN_WEBSERVER=ON                                  -DPLUGIN_WEBSERVER_PORT=\"8080\"                                  -DPLUGIN_WEBSERVER_PATH=\"/var/www/\" \
-DPLUGIN_WEBSHELL=OFF -DPLUGIN_WIFICONTROL=OFF -DPLUGIN_USE_RDK_HAL_WIFI=OFF -DPLUGIN_WEBKITBROWSER_YOUTUBE=ON"

pushd WPEFrameworkPlugins
mkdir -p build
    pushd build
        cmake ${CMOPTS} ${EXTRA_OECMAKE} ..
        make ${MOPTS} install
    popd
popd
fi
