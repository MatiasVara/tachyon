apt-get update
apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils virtinst
rmmod kvm
modprobe -a kvm
