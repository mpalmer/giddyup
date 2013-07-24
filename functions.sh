#!/bin/sh

# This is a file full of helper functions that are of use in hook scripts,
# as well as being common to different scripts in the giddyup deployment
# ecosystem.
#
# These functions rely on the correct, pre-existing global definition of the
# environment variables defined in the "Hook environment" section of
# README.md.  If you attempt to use these functions without those variables
# being set, Bad Things will likely happen.

###########################################################################

# Create a symlink from within the `$RELEASE` into somewhere within
# `$ROOT/shared`.  The relative path within both `$RELEASE` and
# `$ROOT/shared` is given by the first (and only) argument to this function.
#
# Example:
#
#    share some/location
#
# This will create a symlink from $RELEASE/some/location to
# $ROOT/shared/some/location.
#
# NOTE: This function behaves differently depending on whether the symlink
# source (`$RELEASE/some/location`) already exists or not, and whether or
# not the destination exists.  The logic is as follows:
#
# * If the parent directory of the source location (in our example,
#   `$RELEASE/some`) or the destination location (in our example,
#   `$ROOT/shared/some`) does not already exist, it will be created.
#
# * If the source does not exist, then a symlink is created unconditionally.
#   If `$ROOT/shared/some/location` doesn't already exist, the symlink will
#   dangle until something (eg.  the start hook, or the application itself)
#   creates it.
#
# * If the source *does* exist, but the destination does not, then the
#   source will be moved to the destination before the symlink is created. 
#   This allows you to ship a default dataset in your application bundle,
#   safe in the knowledge that future updates won't overwrite it once it's
#   in the `shared` tree.
#
share() {
	local shareditem="$1"

	case "$shareditem" in
		*../*|*/..*)
			echo "Nice try, buddy." >&2
			exit 1
	esac

	local src="${RELEASE}/${shareditem}"
	local dst="${ROOT}/shared/${shareditem}"
	local srcparent="$(dirname "$src")"
	local dstparent="$(dirname "$dst")"
	
	if [ ! -d "$dstparent" ]; then
		mkdir -p "$dstparent"
	fi
	
	if [ ! -d "$srcparent" ]; then
		mkdir -p "$srcparent"
	fi
	
	if [ -e "$src" ]; then
		if [ ! -e "$dst" ]; then
			mv "$src" "$dst"
		fi
		
		# Yes, this'll be a NOOP if we've just done the above
		rm -rf "$src"
	fi

	ln -s "$src" "$dst"
}

# Execute the specified hook.
#
# Example:
#
#     run_hook start
#
# This function will look in the configured hooks directory for either
# a file or directory whose name exactly matches the specified hook name
# (`start` in our example).  If a directory is found, it will attempt to
# execute all the files in that directory.  If a single file is found,
# it will attempt to execute that file.
#
run_hook() {
	local hook="$1"
	local hookdir="$(get_config hookdir)"
	hookdir="${hookdir:-config/hooks}"
	
	if [ -d "${RELEASE}/${hookdir}/${hook}" ]; then
		for f in "${RELEASE}/${hookdir}/${hook}/"*; do
			exec_hook_file "$f"
		done
	else
		exec_hook_file "${RELEASE}/${hookdir}/${hook}"
	fi
}

# Attempts to execute a single hook file, whose fully-qualified path is
# given as the sole argument.  Respects the `autochmodhooks` config variable
# when deciding whether or not to execute the file.
#
# Example:
#
#     exec_hook_file /home/foo/staging/releases/20130229-225960/config/hooks/start/something
#
exec_hook_file() {
	local hook_file="$1"
	local autochmodhooks="$(get_config autochmodhooks)"

	if [ "${autochmodhooks}" = "true" ]; then
		chmod +x $hook_file
	fi

	if [ -x "$hook_file" ]; then
		env - PATH="${PATH}"	 		\
		      APP_ENV="${APP_ENV}"		\
		      ROOT="${ROOT}"			\
		      RELEASE="${RELEASE}"		\
		      NEWREV="${NEWREV}"		\
		      OLDREV="${OLDREV}"		\
		      "$hook_file"
	else
		cat <<EOF >&2
WARNING: file $hook_file does not have executable permissions.
You may want to enable giddyup.autochmodhooks, or fix the permissions.
EOF
	fi
}

# Sets up a bunch of common environment variables and the basic directory
# structures required to install a release.
#
# Takes no arguments and returns nothing.
#
init_env() {
	APP_ENV="$(get_config environment)"

	HOOKDIR="$(get_config hookdir)"
	HOOKDIR="${HOOKDIR:-config/hooks}"

	RELEASE_DATE="$(date +%Y%m%d-%H%M%S)"
	RELEASE="${ROOT}/releases/${RELEASE_DATE}"

	mkdir -p "${ROOT}/shared"
	mkdir -p "${RELEASE}"
}

# Do the hard yards of running hook scripts and re-symlinking the new
# release.  Assumes that `$RELEASE` has been successfully populated with a
# complete release of the project.
#
# Takes no arguments and returns nothing.
#
cycle_release() {
	local keep_releases="$(get_config keepreleases)"
	keep_releases="${keep_releases:-5}"

	run_hook stop

	rm -f current
	ln -s "${RELEASE}" current

	run_hook start

	# Tidy up old releases
	if [ "${keep_releases}" != "0" ]; then
		cd "${ROOT}/releases"
		ls | sort -r | tail -n +$((${keep_releases}+1)) | xargs rm -rf
	fi
}
