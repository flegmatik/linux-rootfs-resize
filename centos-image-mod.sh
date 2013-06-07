#!/bin/bash
# Robert Plestenjak, robert.plestenjak@xlab.si
# tested on CentOS 6.2+ x86_64
#
# depends:
# cloud-utils, https://launchpad.net/cloud-utils 
# HOWTO: add EPEL repo and install 'cloud-utils'
# for Openstack: optional, install 'cloud-init'
#
# what it does:
# - installs itself in '/opt/libexec/centos-mod' directory, change
#   '${install_dir}' to change install path
# - automatic partition resize and filesystem increase of root partition
#   during boot
# - sets elevator scheduler 'noop', change '${elevator}' for different scheduler, 
#   valid values are: deadline, anticipatory, cfq, noop
# - redirects boot log to '/dev/ttyS0' console. Needed for Openstack, so you can 
#   see boot log, change '${console}' if you need
# 
set_elevator=yes
set_console=yes
#
install_dir=/usr/libexec/centos-mod
elevator="noop"
growpart_path="/usr/bin"
console="/dev/ttyS0"
#
#

function deps () {
    for file in ${@}; do
        [ ! -z $(echo $file |grep -o "$lib") ] && 
            cp -v ${file $lib}/
    done
}

function copy-tools () {
    echo "--- copying tools and dependencies ..."
    cp -v ${install_dir}/init-part sbin/
    cp -v ${growpart_path}/growpart sbin/
    cp -v /sbin/sfdisk sbin/
    cp -v /usr/bin/awk bin/
    cp -v /sbin/e2fsck sbin/
    cp -v /sbin/resize2fs sbin/
    deps "($(ldd sbin/sfdisk))"
    deps "($(ldd bin/awk))"
    deps "($(ldd sbin/e2fsck))"
    deps "($(ldd sbin/resize2fs))"
    echo "--- done"
}

# exit if not root
if [ "$USER" != "root" ]; then
    echo "Run as root!"
    exit 1
fi

# exit if no growpart tool
if [ ! -f ${growpart_path}/growpart ]; then
    echo "Growpart tool not found in ${growpart_path}!"
    echo "Get growpart at https://launchpad.net/cloud-utils"
    exit 1
fi

echo "Starting CentOS mod process ..."

# collect system and partitions info
kernel_version=$(uname -r)
root_uuid=$(cat /etc/fstab |grep "UUID.*\/ .*" |awk '{print $1}')
root_part=$(readlink /dev/disk/by-uuid/$(echo ${root_uuid} |sed "s/UUID=//g") |sed "s/[^a-z0-9]//g")
root_dev=$(echo ${root_part} |sed "s/[0-9]//g")

# create install dir
[ ! -d ${install_dir} ] && mkdir -p ${install_dir}

# redirect console to ${console}
if [ "${set_console}" == "yes" ]; then
    console_file=$(cat << eof
# ${console} - agetty
#
# This service maintains a agetty on ${console}.

stop on runlevel [S016]
start on runlevel [23]

respawn
exec agetty -h -L -w /dev/${console} 115200 vt102
eof
)
    echo "${console_file}" > /etc/init/${console}.conf
else
    unset console
fi

# create backup of important files
echo "- backing up grub.conf >> ${install_dir}/grub.conf.$(date +%Y%m%d-%H%M)"
cp /boot/grub/grub.conf ${install_dir}/grub.conf.$(date +%Y%m%d-%H%M)

# prepare initamfs copy
echo -n "- extracting initramfs /boot/initramfs-${kernel_version}.img, size: "
[ "$(uname -m)" == "x86_64" ] && \
    lib=lib64 || \
    lib=lib
[ -d /tmp/initramfs-${kernel_version} ] && \
    rm -rf /tmp/initramfs-${kernel_version}
mkdir /tmp/initramfs-${kernel_version}
cd /tmp/initramfs-${kernel_version}
gunzip -c /boot/initramfs-${kernel_version}.img | cpio -i --make-directories

# modify initramfs
echo "- modify initramfs copy /tmp/initramfs-${kernel_version}"
copy-tools
touch etc/mtab
sed -i "/^source_all pre-mount$/a\init-part \$\{root\}" init

# remove existing initramf mods
echo "- removing all previous mod setups"
rm -fv /boot/initramfs-mod-*

# create new initramfs
echo -n "- new initrams /boot/initramfs-mod-${kernel_version}.img, size: "
find ./ | cpio -H newc -o > /tmp/initrd.cpio
gzip -c /tmp/initrd.cpio > /boot/initramfs-mod-${kernel_version}.img

# grub; set root disk and partition number
[ "${root_dev}" == "sda" ] && grub_disk=0
[ "${root_dev}" == "sdb" ] && grub_disk=1
[ "${root_dev}" == "sdc" ] && grub_disk=2
[ "${root_dev}" == "sdd" ] && grub_disk=3
[ $(echo ${root_dev} |sed "s/[^0-9]//g") == "1" ] && grub_part=0
[ $(echo ${root_dev} |sed "s/[^0-9]//g") == "2" ] && grub_part=1
[ $(echo ${root_dev} |sed "s/[^0-9]//g") == "3" ] && grub_part=2
[ $(echo ${root_dev} |sed "s/[^0-9]//g") == "4" ] && grub_part=3
root_grub=hd${grub_disk}","${grub_part}

# modify grub menu
echo "- setting up grub.conf"
grub_entry="title CentOS mod ${kernel_version}\n\troot (${root_grub})\n\tkernel /boot/vmlinuz-${kernel_version} ro root=${root_uuid} rd_NO_LUKS rd_NO_LVM LANG=en_US.UTF-8 rd_NO_MD SYSFONT=latarcyrheb-sun16 crashkernel=auto KEYBOARDTYPE=pc KEYTABLE=us rd_NO_DM elevator=${elevator} ${console} quiet\n\tinitrd /boot/initramfs-mod-${kernel_version}.img"
# remove existing production entry
grub_entry_start="title CentOS mod ${kernel_version}"
grub_entry_end="\tinitrd \/boot\/initramfs-mod-${kernel_version}.img"
sed -i "/${grub_entry_start}/,/${grub_entry_end}/d" /boot/grub/grub.conf
# insert new entry
sed -i "/^hiddenmenu$/ a ${grub_entry}" /boot/grub/grub.conf

# cleanup
echo "- clean up"
rm -rf /tmp/initramfs-${kernel_version}
rm -f /tmp/initrd.cpio
rm -f /tmp/root_part.tmp

echo
echo "Reboot, choose 'title CentOS ${run_mode}mod ${kernel_version}' in grub"
echo
