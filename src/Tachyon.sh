#!/bin/bash
#
# Tachyon.sh
#
# Use: Tachyon.sh InstanceIp Directory
#
# Copyright (c) 2018-2019 Matias Vara <matiasevara@gmail.com>
# All Rights Reserved
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

app="Tachyon";
appbin="$app.bin";
qemufile="qemu.args";

# get the qemu parameters
iface=`tunctl -b`
qemuparams="-monitor /dev/null -smp 1 -m 256 -nographic -net nic,model=virtio -net tap,ifname=$iface,script=./qemu-ifup -device virtio-blk-pci,drive=drive-virtio-disk0,addr=06"
kvm -kernel $appbin $qemuparams -append $1 -drive file=fat:rw:$2,if=none,id=drive-virtio-disk0 &
