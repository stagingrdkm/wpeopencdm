#!/bin/bash

# Script to run WPEFramework
#
# Author: Damian Wrobel <dwrobel.contractor@libertyglobal.com>


LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/_install/usr/lib:$PWD/_install/usr/lib/wpeframework/plugins
export LD_LIBRARY_PATH

PATH=$PWD/_install/usr/bin:$PATH
export PATH

export WAYLAND_DISPLAY=wayland-0

${GDB} ./_install/usr/bin/WPEFramework
