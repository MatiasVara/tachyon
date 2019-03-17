# Tachyon

## Introduction
Tachyon is a simple webserver that allows access to files by using the http protocol. Tachyon is built on top of toro and it is distributed as an appliance. Tachyon runs alone as a toro appliance thus leveraging on virtual machine's (VM) resources like strong isolation.  

## Features
* Fast instantiation 
* Reduced memory footprint
* Reduced CPU usage
* Strong isolation

## How to develop it
To develop, just run setup.sh and start to play with src/Tachyon.pas

## How to try it
To try Tachyon, first get the latest release from https://github.com/torokernel/tachyon/releases. Then, un tar it and run `install.sh`. The script installs Qemu-KVM among other tools. If everything has been installed correctly, you will get the message:

`rmmod: ERROR: Module kvm is in use by: kvm intel`

Now you have to create a bridge by doing: 

`virsh net-create toro-kvm-network.xml`

We are almost there. You have to invoke `Tachyon` by specifying first the IP of the webserver and second the directory used to serve:
 
`./Tachyon.sh 192.100.200.100 ./TachyonFiles`

You can check that the server is up and running by pinging it. Also, you can get the `index.html`  by doing:

`curl http://192.100.200.100/index.html` 
