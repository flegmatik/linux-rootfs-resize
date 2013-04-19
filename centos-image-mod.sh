#!/bin/bash
# Robert Plestenjak, robert@flegma.net
# tested on CentOS 6.3 x86_64
#
# depends:
# on cloud-utils, https://launchpad.net/cloud-utils 
# script assumes you have 'growpart' accessible at location 
# '/usr/lib/cloud-utils/bin/growpart'
# change '$growpart_path' value if you need
#
# adds:
# - automatic partition and filesystem increase on root partition
# - sets elevator scheduler 'noop', change '$elevator' if you need.
# valid values are: deadline, anticipatory, cfq, noop
# - redirects boot log to '/dev/ttyS0' console so you can see boot
# log in openstack, change '$console' if you need
# 
elevator="noop"
growpart_path="/usr/lib/cloud-utils/bin"
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

function show-help {
    echo "$(basename $0) test ... Won't change partition, only test"
    echo "$(basename $0) help ... This help"
    echo "$(basename $0) prod ... For real! Production mode"
}

if [ "$USER" != "root" ]; then
    echo "Run as root!"
    exit 1
fi
if [ ! -f ${growpart_path}/growpart ]; then
    echo "Growpart tool not found in ${growpart_path}!"
    echo "Get growpart at https://launchpad.net/cloud-utils"
    exit 1
fi
case $1 in
    "test")
        run_mode="test"
        ;;
    "help")
        show-help
  exit 0
        ;;
    "prod")
        run_mode="production"
	;;
    *)
        show-help
	exit 1
        ;;
esac

echo "Starting CentOS mod process in mode: "${run_mode}
install_dir=$(pwd)
kernel_version=$(uname -r)
root_uuid=$(cat /etc/fstab |grep "UUID.*\/ .*" |awk '{print $1}')
root_part=$(readlink /dev/disk/by-uuid/$(echo ${root_uuid} |sed "s/UUID=//g") |sed "s/[^a-z0-9]//g")
root_dev=$(echo ${root_part} |sed "s/[0-9]//g")

if [ "${console}" == "/dev/ttyS0" ]; then
    console_file=$(cat << eof
# ttyS0 - agetty
#
# This service maintains a agetty on ttyS0.

stop on runlevel [S016]
start on runlevel [23]

respawn
exec agetty -h -L -w /dev/ttyS0 115200 vt102
eof
)
    echo "${console_file}" > /etc/init/ttyS0.conf
else
    unset console
fi

echo "- elevator == ${elevator}"
echo "- root partition == ${root_part}"
echo "- redirecting console > ${console}"

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
if [ "$run_mode" == "production" ]; then
    unset run_mode
    sed -i "/^source_all pre-mount$/a\init-part \$\{root\}" init
else
    sed -i "/^source_all pre-mount$/a\init-part \$\{root\} test" init
fi

# remove existing dryrun initramf
echo "- removing all previous mod setups"
rm -fv /boot/initramfs-testmod-*
rm -fv /boot/initramfs-mod-*

# create new initramfs
echo -n "- new initrams /boot/initramfs-${run_mode}mod-${kernel_version}.img, size: "
find ./ | cpio -H newc -o > /tmp/initrd.cpio
gzip -c /tmp/initrd.cpio > /boot/initramfs-${run_mode}mod-${kernel_version}.img

# modify grub menu
echo "- setting up grub.conf"
grub_entry="title CentOS ${run_mode}mod ${kernel_version}\n\troot (hd0,1)\n\tkernel /boot/vmlinuz-${kernel_version} ro root=${root_uuid} rd_NO_LUKS rd_NO_LVM LANG=en_US.UTF-8 rd_NO_MD SYSFONT=latarcyrheb-sun16 crashkernel=auto KEYBOARDTYPE=pc KEYTABLE=us rd_NO_DM elevator=${elevator} ${console} quiet\n\tinitrd /boot/initramfs-${run_mode}mod-${kernel_version}.img"
# remove existing production entry
grub_entry_start="title CentOS mod ${kernel_version}"
grub_entry_end="\tinitrd \/boot\/initramfs-mod-${kernel_version}.img"
sed -i "/${grub_entry_start}/,/${grub_entry_end}/d" /boot/grub/grub.conf
# remove existing test entries
grub_entry_start="title CentOS dryrunmod.*"
grub_entry_end="\tinitrd \/boot\/initramfs-testmod-.*"
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
