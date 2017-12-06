#!/bin/sh

#this script:
#Umounts & clears volumes from previous run of the script
#Creates 500MiB file in /var
#Creates 10 LVM logical volumes (+- 50MB each) in this file
#Mounts them to /mnt/test/vol01 .. vol10 directories


#error exit function
error_exit()
{
	echo "$1" 1>&2
	exit 1
}



#Clean part
i=0
temp=$(losetup --list | grep "/var/test_file")
if [ ! -z  "$temp" ]; then
	while [  $i -lt 10 ]; do
		loop=$(losetup -a | grep "/var/test_file" | head -n $((i+1)) | tail -n 1 | sed 's/:.*//')
		umount -f /dev/mapper/"new_vol_group$i"-"vol$i"
		lvremove -f /dev/"new_vol_group$i"/"vol$i"
		vgremove "new_vol_group$i"
		pvremove $loop
		i=$((i+1))
	done
fi

if [ ! -z  "$temp" ]; then
	i=0
	while [  $i -lt 10 ]; do
		loop="$(losetup -a | grep "/var/test_file" | tail -n 1 | sed 's/:.*//')"
		losetup -v -d $loop
		i=$((i+1))
	done
fi
#don't need to clean this files, because script will always create them agian in creating part
#but just to know what everything script creates if you want to clean everything
if [ -f /var/test_file ]; then
	rm /var/test_file
fi

i=1
while  [  $i -lt 11 ]; do
	if [ -d /mnt/test/vol$i ]; then
		rmdir /mnt/test/vol$i
	fi
	i=$((i+1))
done
if [ -d /mnt/test ]; then
	rmdir /mnt/test
fi

#creating part

#sizes of new file
block_size=1024
num_blocks=512000
dd if=/dev/zero of=/var/test_file bs=$block_size count=$num_blocks
if [ "$?" -ne "0" ]; then
	error_exit "Not enough space to create new file with size $((block_size * num_blocks)) bytes."
fi

j=0
while  [  $j -lt 10 ]; do
	offset=""
	if [ $j -eq 0 ]; then
		offset=0
	else
		off_size=$((off_size+50))
		offset=$off_size"M"
	fi
	losetup --find /var/test_file --offset $offset \
		--sizelimit 50M /var/test_file \
		/
	j=$((j+1))
done

i=0
while [  $i -lt 10 ]; do
	loop=$(losetup -a | grep "/var/test_file" | head -n $((i+1)) | tail -n 1 | sed 's/:.*//')
	vgcreate "new_vol_group$i" $loop
	lvcreate -L 48MiB -n "vol$i" "new_vol_group$i"
	mkfs.ext4 /dev/"new_vol_group$i"/"vol$i"
	mkdir -p /mnt/test/"vol$((i+1))"
	mount /dev/mapper/"new_vol_group$i"-"vol$i" /mnt/test/"vol$((i+1))"
	i=$((i+1))
done