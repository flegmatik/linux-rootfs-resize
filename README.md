linux-rootfs-resize
===================

Rework of my previous project, that was limited only to CentOS 6.x.

This tool creates new initrd (initramfs) image with abbilitie to resize root
filesystem over available space. Tipically you need this when you provision
your virtual machine on OpenStack cloud for the first time (your image 
becomes flavor aware)

This code was successfuly tested on: CentOS 6.4, Debian 6 and Debian 7.2

DEPENDENCIES:
 - cloud-utils (https://launchpad.net/cloud-utils)
