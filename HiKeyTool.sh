#!/bin/bash

# -----------------------------------
#
#  Developed by Fonic
#  Modified: 04/05/16
#
#  Based on:
#  https://github.com/96boards/documentation/wiki/HiKeyUEFI#install-from-prebuilt-binaries
#  https://github.com/96boards/documentation/wiki/HiKeyUEFI#flash-binaries-to-emmc-
#  https://github.com/96boards/documentation/wiki/HiKeyGettingStarted#3-installing-build-of-android-open-source-project
#
# -----------------------------------


# ---------------------------------
#  Functions
# ---------------------------------

# Die on error [$1: reason]
function die() {
	echo -e "\033[1;31mError: $1\033[0m\n"
	exit 1
}

# Abort [no params]
function abort() {
	echo
	exit 1
}

# Print notice [$1: text]
function notice() {
	echo -e "\033[1;33m$1\033[0m"
}

# Ask yes/no question [$1: question]
function askyesno() {
	local input
	while [ true ]; do
		echo -en "\033[1m$1 (y/n)?\033[0m "
		read -n 1 input
		echo
		[ "$input" == "y" ] && return 0
		[ "$input" == "n" ] && return 1
	done
}

# Download file [$1: URL, $2: renameto]
function download() {
	if [ "$2" == "" ]; then
		echo -n "Downloading '$(basename "$1")'... "
		wget "$1" &>/dev/null
	else
		echo -n "Downloading '$2'... "
		wget "$1" -O "$2" &>/dev/null
	fi
	[ $? -eq 0 ] && echo -e "\033[1;32mok\033[0m" || echo -e "\033[1;31mfailed\033[0m"
}

# Copy file [$1: file, $2: renameto]
function copy() {
	if [ "$2" == "" ]; then
		echo -n "Copying '$(basename "$1")'... "
		cp --preserve=timestamps "$1" . &>/dev/null
	else
		echo -n "Copying '$2'... "
		cp --preserve=timestamps "$1" "$2" &>/dev/null
	fi
	[ $? -eq 0 ] && echo -e "\033[1;32mok\033[0m" || echo -e "\033[1;31mfailed\033[0m"
}

# Fetch file [$1: source, $2: renameto]
function fetch() {
	local proto="${1%://*}"
	local file="${1##*://}"
	if [ "$proto" == "file" ]; then
		copy "$file" "$2"
	elif [ "$proto" == "http" ] || [ "$proto" == "https" ] || [ "$proto" == "ftp" ]; then
		download "$1" "$2"
	else
		echo -e "Fetching '$(basename "$file")'... \033[1;31mfailed\033[0m (unknown protocol '$proto')"
	fi
}

# Extract .tar.xz file [$1: file]
function extractxz() {
	echo -n "Extracting '$1'... "
	tar -Jxf "$1" &>/dev/null
	[ $? -eq 0 ] && echo -e "\033[1;32mok\033[0m" || echo -e "\033[1;31mfailed\033[0m"
}

# Unzip .img.gz file [$1: file]
function unzipgz() {
	echo -n "Unzipping '$1'... "
	gunzip "$1" &>/dev/null
	[ $? -eq 0 ] && echo -e "\033[1;32mok\033[0m" || echo -e "\033[1;31mfailed\033[0m"
}

# Rename file [$1: from, $2: to]
function rename() {
	echo -n "Renaming '$1' to '$2'... "
	mv "$1" "$2" &>/dev/null
	[ $? -eq 0 ] && echo -e "\033[1;32mok\033[0m" || echo -e "\033[1;31mfailed\033[0m"
}

# Delete file [$1: file]
function delete() {
	echo -n "Deleting '$1'... "
	rm "$1" &>/dev/null
	[ $? -eq 0 ] && echo -e "\033[1;32mok\033[0m" || echo -e "\033[1;31mfailed\033[0m"
}

# Check file [$1: file]
filesok="true"
function check() {
	echo -n "Checking file '$1'... "
	stat "$1" &>/dev/null
	if [ $? -eq 0 ]; then
		echo -e "\033[1;32mfound\033[0m"
	else
		echo -e "\033[1;31mmissing\033[0m"
		filesok="false"
	fi
}


# ---------------------------------
#  Main
# ---------------------------------

# Print header
echo -e "\n\033[1m-=| HiKey Tool |=-\033[0m\n"

# Process command line
arg_config="$1"
arg_action="$2"
if [ "$arg_config" == "" ] || [ "$arg_action" != "fetch" ] && [ "$arg_action" != "flash" ] && [ "$arg_action" != "sdcard" ]; then
	echo "Usage: $0 <config> <fetch|flash|sdcard>"
	echo
	exit 1
fi

# Read configuration
source "$arg_config" 2>/dev/null || die "Failed to read configuration '$arg_config'"

# Verify configuration
[ "$cfg_title" != "" ] || die "Missing configuration title (cfg_title)"
[ "$cfg_type" == "aosp_local" ] || [ "$cfg_type" == "aosp_96boards" ] || [ "$cfg_type" == "debian_96boards" ] || die "Unknown config type '$cfg_type' (cfg_type)"
[ "$src_loader" != "" ] || die "Missing source for boot loader (src_loader)"
[ "$src_images" != "" ] || die "Missing source for images (src_images)"
if [ "$cfg_type" == "debian_96boards" ]; then
	[ "$image_boot" != "" ] || die "Missing filename for boot image (image_boot)"
	[ "$image_root" != "" ] || die "Missing filename for root image (image_root)"
fi

# Print configuration
echo "Title:	$cfg_title"
echo "Type:	$cfg_type"
echo "Loader:	$src_loader"
echo "Images:	$src_images"
if [ "$cfg_type" == "debian_96boards" ]; then
	echo "Boot:	$image_boot"
	echo "Root:	$image_root"
fi
echo


#
# Fetch mode
#
if [ "$arg_action" == "fetch" ]; then

	# Print notice
	notice "Ready to fetch files. Previously fetched files will be deleted.\n"
	askyesno "Proceed" || abort
	echo

	# Prepare target folder
	rm -rf "./images/$cfg_title" &>/dev/null || die "Remove dir 'images/$cfg_title' failed"
	mkdir -p "images/$cfg_title" &>/dev/null || die "Create dir 'images/$cfg_title' failed"
	cd "images/$cfg_title" &>/dev/null || die "Change to dir 'images/$cfg_title' failed"

	# Fetch bootloader + HiKey recovery tool
	fetch "${src_loader}/hisi-idt.py"
	fetch "${src_loader}/l-loader.bin"
	if [ "$cfg_type" == "aosp_local" ] || [ "$cfg_type" == "aosp_96boards" ]; then
		fetch "${src_loader}/ptable-aosp-8g.img" "ptable.img"
	elif [ "$cfg_type" == "debian_96boards" ]; then
		fetch "${src_loader}/ptable-linux-8g.img" "ptable.img"
	fi
	fetch "${src_loader}/fip.bin"
	fetch "${src_loader}/nvme.img"

	# Config type 'aosp_local'
	if [ "$cfg_type" == "aosp_local" ]; then

		# Fetch images
		fetch "${src_images}/boot_fat.uefi.img" "boot.img"
		fetch "${src_images}/cache.img"
		fetch "${src_images}/system.img"
		fetch "${src_images}/userdata.img"

	# Config type 'aosp_96boards'
	elif [ "$cfg_type" == "aosp_96boards" ]; then

		# Fetch images
		fetch "${src_images}/boot_fat.uefi.img.tar.xz" "boot.img.tar.xz"
		fetch "${src_images}/cache.img.tar.xz"
		fetch "${src_images}/system.img.tar.xz"
		fetch "${src_images}/userdata-8gb.img.tar.xz" "userdata.img.tar.xz"

		# Detect system.img.tar.xz license quirk
		if file "system.img.tar.xz" | grep -q HTML 2>/dev/null; then
			echo
			echo "Please download 'system.img.tar.xz' to '$(pwd)' and extract using 'tar -Jxf'."
			echo "-> ${src_images}/system.img.tar.xz"
			echo
		fi

		# Extract images
		extractxz "boot.img.tar.xz"
		extractxz "cache.img.tar.xz"
		extractxz "system.img.tar.xz"
		extractxz "userdata.img.tar.xz"

		# Rename files
		rename "boot_fat.uefi.img" "boot.img"
		rename "userdata-8gb.img" "userdata.img"

		# Remove archives
		delete "boot.img.tar.xz"
		delete "cache.img.tar.xz"
		delete "system.img.tar.xz"
		delete "userdata.img.tar.xz"

	# Config type 'debian_96boards'
	elif [ "$cfg_type" == "debian_96boards" ]; then

		# Fetch images
		fetch "${src_images}/${image_boot}" "boot.img.gz"
		fetch "${src_images}/${image_root}" "root.img.gz"

		# Unzip images
		unzipgz "boot.img.gz"
		unzipgz "root.img.gz"

	fi

#
# Flash mode
#
elif [ "$arg_action" == "flash" ]; then

	# Check if root
	[[ ${EUID} == 0 ]] || die "You must be root to do this"

	# Change directory
	cd "images/$cfg_title" &>/dev/null || die "Change to dir 'images/$cfg_title' failed"

	# Check files
	check "l-loader.bin"
	check "fip.bin"
	check "ptable.img"
	check "nvme.img"
	check "hisi-idt.py"
	check "boot.img"
	if [ "$cfg_type" == "aosp_local" ] || [ "$cfg_type" == "aosp_96boards" ]; then
		check "cache.img"
		check "system.img"
		check "userdata.img"
	elif [ "$cfg_type" == "debian_96boards" ]; then
		check "root.img"
	fi
	echo
	[ "$filesok" == "true" ] || die "Required files are missing"

	# Print notice
	notice "Ready to flash bootloader and partition table. Set jumpers for recovery\nmode, connect Micro-USB, power on, wait a few seconds and continue.\n"
	askyesno "Continue" || abort
	echo

	# Flash bootloader + partition table (NOTE: requires Python 2.x and dev-python/pyserial)
	python2 -c "import serial" &>/dev/null	|| die "Python 2.x module 'serial' missing"
	python2 hisi-idt.py --img1=l-loader.bin	|| die "Flashing 'l-loader.bin' failed"
	sleep 3s
	fastboot flash ptable ptable.img	|| die "Flashing 'ptable.img' failed"
	echo

	# Print notice
	notice "Ready to flash images. Set jumpers for fastboot mode and continue.\n"
	askyesno "Continue" || abort
	echo

	# Flash images
	fastboot reboot					|| die "Rebooting fastboot failed"
	sleep 3s
	fastboot flash fastboot fip.bin			|| die "Flashing 'fip.bin' failed"
	fastboot flash nvme nvme.img			|| die "Flashing 'nvme.img' failed"
	fastboot flash boot boot.img			|| die "Flashing 'boot.img' failed"
	if [ "$cfg_type" == "aosp_local" ] || [ "$cfg_type" == "aosp_96boards" ]; then
		fastboot flash cache cache.img		|| die "Flashing 'cache.img' failed"
		fastboot flash system system.img	|| die "Flashing 'system.img' failed"
		fastboot flash userdata userdata.img	|| die "Flashing 'userdata.img' failed"
	elif [ "$cfg_type" == "debian_96boards" ]; then
		fastboot flash system root.img		|| die "Flashing 'root' failed"
	fi
	echo

	# Print notice
	notice "Remove Micro-USB, set jumpers for normal operation mode and power cycle\nor reboot using the following command: 'fastboot reboot'."

#
# SD card mode
#
elif [ "$arg_action" == "sdcard" ]; then

	notice "For now, installing to SD card cannot be automated since there seems to be no"
	notice "proper documentation regarding the boot process when booting from SD cards."
	notice "This feature will be added as soon as there's proper documentation available."
	
fi
echo
