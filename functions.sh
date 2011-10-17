#!/bin/sh

share() {
	local shareditem="$1"
	local shareditemdir="?"
	
	if [ -d "${RELEASE}/${shareditem}" ]; then
		shareditemdir="y"
	else
		shareditemdir="n"
	fi

	rm -rf "${RELEASE}/${shareditem}"

	if [ ! -e "${ROOT}/shared/${shareditem}" ]; then
		if [ "$shareditemdir" = "y" ]; then
			mkdir -p "${ROOT}/shared/${shareditem}"
		elif [ "$shareditemdir" = "n" ]; then
			mkdir -p "$(dirname "${ROOT}/shared/${shareditem}")"
		fi
	fi
	
	ln -s "${ROOT}/shared/${shareditem}" "${RELEASE}/${shareditem}"
}
