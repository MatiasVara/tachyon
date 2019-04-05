#!/bin/bash
#
# Build.sh
#
# Copyright (c) 2003-2018 Matias Vara <matiasevara@gmail.com>
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

# remove all compiled files
rm -f ../torokernel/rtl/*.o ../torokernel/rtl/*.ppu
rm -f ../torokernel/rtl/drivers/*.o ../torokernel/rtl/drivers/*.ppu

# remove the application
rm -f $app "$app.o"

fpc -s -TLinux $2 -dToroHeadLess -O2 $app.pas -Fu../torokernel/rtl/ -Fu../torokernel/rtl/drivers -MObjfpc
ld -S -nostdlib -nodefaultlibs -T $app.link  -o kernel64.elf64
readelf -SW "kernel64.elf64" | python ../torokernel/builder/getsection.py 0x440000 kernel64.elf64 kernel64.section
objcopy --add-section .KERNEL64="kernel64.section" --set-section-flag .KERNEL64=alloc,data,load,contents ../torokernel/builder/multiboot.o kernel64.o
readelf -sW "kernel64.elf64" | python ../torokernel/builder/getsymbols.py "start64"  kernel64.symbols
ld -melf_i386 -T ../torokernel/builder/link_start64.ld -T kernel64.symbols kernel64.o -o $app.bin
