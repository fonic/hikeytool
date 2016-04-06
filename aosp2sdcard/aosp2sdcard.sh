#!/bin/bash

# -------------------------------------------------
#
#  aosp2sdcard.sh v1.2
#
#  Developed by Fonic (https://github.com/fonic)
#  Modified: 04/06/16
#
# -------------------------------------------------


# ---------------------------------
#  Functions
# ---------------------------------

# Abort program [no params]
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

# Print action [$1: action]
function action() {
	#echo -en "\033[1m$1... \033[0m"
	echo -en "$1... "
}

# Print result [no params]
function result() {
	if [ $? -eq 0 ]; then
		echo -e "\033[1;32mok\033[0m"
	else
		echo -e "\033[1;31mfailed\033[0m"
		exit 1
	fi
}


# ---------------------------------
#  Main
# ---------------------------------

# Check command line
if [ "$2" == "" ]; then

	# Print usage
	echo -e "\n\033[1mUsage:\033[0m\n$0 <path_to_images> <device>\n"

	# Compose list of removable devices with size > 0
	list1=$(grep -l '1' /sys/block/sd*/removable | xargs -n 1 dirname)
	list2=$(grep -l -v -w '0' /sys/block/sd*/size | xargs -n 1 dirname)
	remdevs=$(echo -e "$list1\n$list2" | sort | uniq -d | sed "s/\/sys\/block/\/dev/g")

	# List available devices
	echo -e "\033[1mRemovable devices:\033[0m"
	if [ "$remdevs" == "" ]; then
		echo "none"
	else
		for remdev in $remdevs; do
			echo "$remdev"
		done
	fi
	echo

	# Exit
	exit 1

fi
image="$1"
device="$2"
ptable="$(pwd)/ptable-sdcard.img"
simg2img="$(pwd)/simg2img/simg2img"

# Check if root
if [[ ${EUID} != 0 ]]; then
	echo "You must be root to do this"
	exit 1
fi

# Print notice
echo
notice "*** DOUBLE CHECK that you have specified the correct device ***"
notice "Ready to write to SD card. All data on the card will be erased."
echo
askyesno "Continue" || abort
echo

# Build simg2img
if [[ ! -x "$simg2img" ]]; then
	action "Building simg2img"
	(cd simg2img && make) &>/dev/null
	result
fi

# Change to image directory
action "Changing directory"
cd "$image" &>/dev/null
result

exit 0

# Create mount points
action "Creating mountpoints"
mkdir -p "sdcard" "image" &>/dev/null
result

# Write partition table
action "Writing partition table"
dd if="$ptable" of="$device" &>/dev/null
result

# Re-read partition table
action "Re-reading partition table"
partprobe "$device" &>/dev/null
result

# Create filesystems
action "Creating boot filesystem"
mkfs.vfat -n boot "${device}1" &>/dev/null
result
action "Creating system filesystem"
mkfs.ext4 -q -L system "${device}2" &>/dev/null
result
action "Creating cache filesystem"
mkfs.ext4 -q -L cache "${device}3" &>/dev/null
result
action "Creating data filesystem"
mkfs.ext4 -q -L data "${device}4" &>/dev/null
result

# Copy boot partition contents
action "Mounting boot image"
mount "boot.img" image &>/dev/null
result
action "Mounting boot partition"
mount "${device}1" sdcard &>/dev/null
result
action "Copying boot contents"
cp -a image/* sdcard &>/dev/null
result
action "Syncing"
sync &>/dev/null
result
action "Unmounting"
umount image sdcard &>/dev/null
result

# Copy system partition contents
action "Converting system image"
"$simg2img" system.img system.img.raw
result
action "Mounting system image"
mount "system.img.raw" image &>/dev/null
result
action "Mounting system partition"
mount "${device}2" sdcard &>/dev/null
result
action "Copying system contents"
cp -a image/* sdcard &>/dev/null
result
action "Syncing"
sync &>/dev/null
result
action "Unmounting"
umount image sdcard &>/dev/null
result

# Copy data partition contents
action "Converting data image"
"$simg2img" userdata.img userdata.img.raw
result
action "Mounting data image"
mount "userdata.img.raw" image &>/dev/null
result
action "Mounting data partition"
mount "${device}4" sdcard &>/dev/null
result
action "Copying data contents"
cp -a image/* sdcard &>/dev/null
result
action "Syncing"
sync &>/dev/null
result
action "Unmounting"
umount image sdcard &>/dev/null
result
