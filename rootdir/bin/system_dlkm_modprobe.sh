#! /vendor/bin/sh
#=============================================================================
# Copyright (c) 2022 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

SYSTEM_DLKM_DIR="/system_dlkm/lib/modules"
VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"

MODPROBE="/vendor/bin/modprobe"

# Our image packages metadata at the module root; also accept release directories.
for modules_load in "${SYSTEM_DLKM_DIR}/modules.load" "${SYSTEM_DLKM_DIR}"/*/modules.load ;
do
	if [ ! -f "${modules_load}" ]; then
		continue
	fi
	module_dir=${modules_load%/*}
	if [ -e ${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist ] && grep -q blocklist ${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist; then
		blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${VENDOR_DLKM_DIR}/system_dlkm.modules.blocklist | sed -e 's/-/_/g' -e 's/^/-e /')"
	else
		# Use pattern that won't be found in modules list so that all modules pass through grep below
		blocklist_expr="-e %"
	fi
	# Filter out modules in blocklist - we would see unnecessary errors otherwise
	load_modules=$(grep -w -v ${blocklist_expr} "${modules_load}")
	set -- ${load_modules}
	if [ "$#" -eq 0 ]; then
		exit 0
	fi
	first_module=$1
	shift
	if ! ${MODPROBE} -b -s -d "${module_dir}" -a "${first_module}" > /dev/null ; then
		exit 1
	fi
	# load modules individually in case one of them fails to init
	module_pids=
	for module in "$@"; do
		( ${MODPROBE} -b -s -d "${module_dir}" -a "${module}" > /dev/null ) &
		module_pids="${module_pids} $!"
	done

	load_status=0
	for module_pid in ${module_pids}; do
		if ! wait "${module_pid}"; then
			load_status=1
		fi
	done

	exit "${load_status}"
done

exit 1
