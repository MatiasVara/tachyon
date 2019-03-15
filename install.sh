apt-get update
apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils virtinst uml-utilities
rmmod kvm
modprobe -a kvm
