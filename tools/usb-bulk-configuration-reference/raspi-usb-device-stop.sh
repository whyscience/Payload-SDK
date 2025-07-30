#!/bin/bash

cd /sys/kernel/config/usb_gadget
echo "" > pi4/UDC
rmdir pi4/configs/c.1/strings/0x409
rm -f pi4/configs/c.1/rndis.usb0
rmdir pi4/functions/rndis.usb0/
rm -f pi4/os_desc/c.1
rmdir pi4/configs/c.1/
rmdir pi4/strings/0x409
rmdir pi4

exit 0