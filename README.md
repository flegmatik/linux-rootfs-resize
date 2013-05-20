centos-image-resize
===================

Tool for resizing virtual machines during boot. I've made this tool for use 
with Openstack.

DEPENDS:
Depends on growpart tool https://launchpad.net/cloud-utils. Script assumes 
you have growpart accessible at '/usr/lib/cloud-utils/bin/growpart'

SETUP:
Run ./centos-image-mod.sh, it will modify initrd image and grub menu. It will 
also copy itself to /usr/libexec/centos-image-mod directory.

it modifies:
- initrd
- grub.conf
 - elevator mode (noop by default)
 - redirects boot log from STDOUT to /dev/ttyS0
