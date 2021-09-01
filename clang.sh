#! /bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# Costumize
KERNEL="[CLANG]SiLonT"
DEVICE="Mi439"
KERNELNAME="${KERNEL}-${DEVICE}-$(date +%y%m%d-%H%M)"
TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
ZIPNAME="${KERNELNAME}.zip"

# EnvSetup
DEFCONFIG=mi439-perf_defconfig
KBUILD_BUILD_USER="Chuck"
KBUILD_BUILD_HOST=GengKapak
export CHATID="-1001429581761"
export KBUILD_BUILD_HOST KBUILD_BUILD_USER

export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
export CI_BRANCH=$DRONE_BRANCH

# Check Kernel Version
KERVER=$(make kernelversion)

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

##-----------------------------------------------------##

clone() {
	echo " "
	msg "|| Cloning Clang ||"
	git clone --depth=1 -b master https://github.com/silont-project/silont-clang clang-llvm --no-tags --single-branch

		# Toolchain Directory defaults to clang-llvm
	TC_DIR=$KERNEL_DIR/clang-llvm

	msg "|| Cloning Anykernel ||"
	git clone --depth 1 --no-single-branch https://github.com/Chuck439/AnyKernel3.git -b master
}

##------------------------------------------------------##

exports() {
	export ARCH=arm64
	export SUBARCH=arm64
	export token=$TELEGRAM_TOKEN

	KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
	PATH=$TC_DIR/bin/:$PATH

	export PATH KBUILD_COMPILER_STRING
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(($(nproc --all) + 2))
	export PROCS
}

##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <code>Build Number : </code><b>$DRONE_BUILD_NUMBER</b>"
}

##----------------------------------------------------------##

build_kernel() {

 	tg_post_msg "<b>🔨 $KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>HEAD : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>" "$CHATID"
 	make O=out $DEFCONFIG CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LD=ld.lld

	msg "|| Started Compilation ||"
	BUILD_START=$(date +"%s")
	make -j"$PROCS" O=out CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LD=ld.lld CC=clang
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb ]
	    then
	    	msg "|| Kernel successfully compiled ||"
			gen_zip
		else
		tg_post_msg "<b>❌ Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>" "$CHATID"
		fi

}

##--------------------------------------------------------------##

gen_zip() {
        msg "|| Zipping into a flashable zip ||"
        mv "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb AnyKernel3/Image.gz-dtb
        if [ $BUILD_DTBO = 1 ]
        then
                mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
        fi
        cd AnyKernel3 || exit
        zip -r9 "${TEMPZIPNAME}" ./*

        # Sign the zip before sending it to Telegram
        curl -sLo zipsigner-4.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel3/master/zipsigner-4.0.jar
        java -jar zipsigner-4.0.jar "${TEMPZIPNAME}" "${ZIPNAME}"
        tg_post_build "$ZIPNAME" "$CHATID" "✅ Build took : $((DIFF /60)) minute(s) and $((DIFF % 60)) second(s)"
        cd ..
}

clone
exports
build_kernel

##----------------*****-----------------------------##
