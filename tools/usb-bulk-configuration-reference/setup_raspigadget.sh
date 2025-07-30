#!/bin/bash
set -ex
sudo mkdir -p /opt/rasp-usb-config
sudo mkdir -p /opt/rasp-usb-config/build
sudo cp ./build/startup_bulk /opt/rasp-usb-config/build/
sudo cp raspi-usb-device-stop.sh raspi-usb-device-start.sh /opt/rasp-usb-config/
sudo cp raspigadget.service /etc/systemd/system/
sudo chmod +x /opt/rasp-usb-config/*.sh
sudo systemctl daemon-reload
sudo systemctl enable raspigadget.service
# sudo systemctl start raspigadget.service


## check randis
# ifconfig
# ps -ef | grep startup_bulk
## check bulk
# ls /dev/usb-ffs/bulk
## on PC
# lsusb -d 0955:7020 -v
