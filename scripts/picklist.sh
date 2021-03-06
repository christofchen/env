#!/bin/bash

set -e -o pipefail

query_submitted_together() {
	change=$1
	curl -s -H 'Accept-Type: application/json' "https://review.lineageos.org/changes/${change}/submitted_together" | tail -n +2 | jq -r '.[]._number'
}

repopick_chain() {
	local chain_top=$1

	submitted_together=($(query_submitted_together ${chain_top}))
	for ((i=${#submitted_together[@]} - 1; i >= 0; i--)); do
		change=${submitted_together[i]}
		# Check for a number of commits equal to double the chain's length
		repopick -c $((2 * ${#submitted_together[@]})) ${change}
	done
}

clean() {
	export BUILD_PWD="${PWD}"

	repo forall -vc "${BUILD_PWD}/${0} perform_cleanup \${REPO_PATH}"
	repo sync --force-sync -j 8
}

perform_cleanup() {
	excludearray="vendor/lenovo device/xiaomi/msm8956-common kernel/xiaomi/msm8956 vendor/xiaomi device/lenovo/YTX703-common"
	cd ${BUILD_PWD}
	repo="$1"
	echo -n "${repo} "

	if echo "${excludearray}" | grep -q "${1}"; then
		echo "Skipping"
	else
		echo "Clean up now"
		git -C ${repo} clean -fd
		git -C ${repo} reset --hard
		repo sync -d ${repo}
	fi
}

pick() {
	local rice=false

	while [ $# -ne 0 ]; do
		case $1 in
		--rice)
			rice=true
			;;
		esac
		shift
	done

	source build/envsetup.sh

	repopick_chain 240046 # device/lenovo/YTX703-common
	repopick_chain 239527 # extract_utils
	repopick -c 100 230224 # init: run timekeep service as system user

	# hal warnings
	repopick_chain 239155 # msm8952 media-caf
	repopick_chain 239159 # msm8952 audio-caf

	# sepolicy
	repopick -c 100 230613 # Allow webview_zygote to read /dev/ion

	repopick -t "pie-aosp-wfd"

	if [ ${rice} = true ]; then
		git -C device/lenovo/YTX703-common am ${ANDROID_BUILD_TOP}/env/dt2w-patches/device/*.patch
		git -C kernel/lenovo/msm8976 am ${ANDROID_BUILD_TOP}/env/dt2w-patches/kernel/*.patch
	fi
}

usage() {
	echo "$0 clean"
	echo "$0 pick"
}

case ${1:-x} in
clean)
	shift
	clean $@
	;;
pick)
	shift
	pick $@
	;;
perform_cleanup)
	shift
	perform_cleanup $@
	;;
*)
	usage
esac

