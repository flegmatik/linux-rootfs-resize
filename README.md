centos-image-resize
===================

Tool for resizing virtual machines during boot. I've made this tool for use 
with Openstack.

DEPENDS:
Depends on growpart tool https://launchpad.net/cloud-utils.
Add EPEL repo and install cloud-utils, or do it manually
For Openstack, I also recommend you to install cloud-init

SETUP:
Run ./centos-image-mod.sh, it will modify initrd image and grub menu. It will 
also copy itself to /usr/libexec/centos-image-mod directory.

it modifies:
- initrd
- grub.conf
 - elevator mode (noop by default)
 - redirects boot log from STDOUT to /dev/ttyS0
