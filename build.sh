# !/bin/bash

D_CUR=$(pwd)
D_AOSP=$D_CUR/../android-7.1.2_r39
D_X86VBOX=$D_AOSP/device/generic/virtualbox

# Build device armemu
cd $D_AOSP

export JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4g"
$D_AOSP/prebuilts/sdk/tools/jack-admin kill-server
$D_AOSP/prebuilts/sdk/tools/jack-admin start-server

. build/envsetup.sh
lunch virtualbox-eng

cd $D_X86VBOX
make all -j8

cd $D_X86VBOX
. debug.sh

cd $D_CUR

sudo exportfs -a
