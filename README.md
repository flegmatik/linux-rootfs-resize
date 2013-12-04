linux-rootfs-resize
===================

Rework of my previous project, that was limited only to CentOS 6.x.

This tool creates new initrd (initramfs) image with ability to resize root filesystem 
over available space. Tipically you need this when you provision your virtual machine on 
OpenStack cloud for the first time (your image becomes flavor aware)

Root filesystem on LVM is also supported. 

For now, filesystem resize is limited to ext2, ext3 and ext4 (resize2fs).

This code was successfuly tested on: CentOS 6.4, Debian 6 and Debian 7.2

DEPENDENCIES:

    cloud-utils (https://launchpad.net/cloud-utils)

INSTALL: 

    Install git, clone this project on your machine, make 'install' executable and run it.

On CentOS:

    yum install git
    git clone https://github.com/flegmatik/linux-rootfs-resize.git
    cd linux-rootfs-resize
    chmod +x install
    ./install

Tool is designed in modular fashion, so support for other distributions can be added without much work (I hope).
