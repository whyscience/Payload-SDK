#!/bin/bash

# The IP address shared by all USB network interfaces created by this script.
net_ip=192.168.42.120
# The associated netmask.
net_mask=255.255.0.0

enable_vcom=0
enable_rndis=0
enable_bulk=1

startup_bulk_dir=$(dirname "$0")
startup_bulk_exe=${startup_bulk_dir}/build/startup_bulk

if [ ! -d /sys/kernel/config/usb_gadget ]; then
    if ! $(grep -q dtoverlay=dwc2 /boot/config.txt) ; then
        echo -e "\n\n\n## customized\n# for op-sdk enable USB device RNDIS\n[all]\ndtoverlay=dwc2" >> /boot/config.txt
        init 6
    fi

    if ! $(grep -q modules-load=dwc2 /boot/cmdline.txt) ; then
        sed -i 's/rootwait /&modules-load=dwc2 /' /boot/cmdline.txt
        init 6
    fi

    if ! $(grep -q libcomposite /etc/modules) ; then
        echo -e "\n\n\n## customized\n# for op-sdk enable USB device RNDIS\nlibcomposite" >> /etc/modules
        init 6
    fi

    exit 1
fi

modprobe g_ether
rmmod g_ether
sleep 1

if [ ! -d /sys/kernel/config/usb_gadget/pi4 ]; then
    mkdir -p /sys/kernel/config/usb_gadget/pi4
    cd /sys/kernel/config/usb_gadget/pi4
        echo 0x2ca3 > idVendor # Linux Foundation
        echo 0xF001 > idProduct # Multifunction Composite Gadget

        if [ ${enable_vcom} -eq 1 ]; then
            echo 0xF002 > idProduct # Multifunction Composite Gadget
        fi

        if [ ${enable_rndis} -eq 1 ]; then
            echo 0xF003 > idProduct # Multifunction Composite Gadget
        fi

        if [ ${enable_bulk} -eq 1 ]; then
            echo 0xF001 > idProduct # Multifunction Composite Gadget
        fi

        echo 0x0001 > bcdDevice # v1.0.0
        echo 0x0200 > bcdUSB # USB2

        echo 0xEF > bDeviceClass
        echo 0x02 > bDeviceSubClass
        echo 0x01 > bDeviceProtocol

        mkdir -p strings/0x409
            echo "psdk-rpi4b" > strings/0x409/serialnumber
            echo "raspberry" > strings/0x409/manufacturer
            echo "PI4" > strings/0x409/product

        cfg=configs/c.1

        mkdir -p "${cfg}"
            echo 0x80 > ${cfg}/bmAttributes
            echo 250 > ${cfg}/MaxPower

        cfg_str=""

        if [ ${enable_rndis} -eq 1 ]; then
            cfg_str="${cfg_str}+RNDIS"
            func=functions/rndis.usb0
            mkdir -p "${func}"
                ln -sf "${func}" "${cfg}"

            # Informs Windows that this device is compatible with the built-in RNDIS
            # driver. This allows automatic driver installation without any need for
            # a .inf file or manual driver selection.
            echo 1 > os_desc/use
            echo 0xcd > os_desc/b_vendor_code
            echo MSFT100 > os_desc/qw_sign
                echo RNDIS > "${func}/os_desc/interface.rndis/compatible_id"
                echo 5162001 > "${func}/os_desc/interface.rndis/sub_compatible_id"

            ln -sf "${cfg}" os_desc
        fi

        if [ ${enable_vcom} -eq 1 ]; then
            cfg_str="${cfg_str}+ACM0"
            func=functions/acm.gs0
            mkdir -p "${func}"
            ln -sf "${func}" "${cfg}"
        fi

        if [ ${enable_bulk} -eq 1 ]; then
            mkdir -p /dev/usb-ffs

            cfg_str="${cfg_str}+BULK1"
            mkdir -p /dev/usb-ffs/bulk1
            func=functions/ffs.bulk1
            mkdir -p "${func}"
            ln -sf "${func}" "${cfg}"
            mount -o mode=0777,uid=2000,gid=2000 -t functionfs bulk1 /dev/usb-ffs/bulk1

            cfg_str="${cfg_str}+BULK2"
            mkdir -p /dev/usb-ffs/bulk2
            func=functions/ffs.bulk2
            mkdir -p "${func}"
            ln -sf "${func}" "${cfg}"
            mount -o mode=0777,uid=2000,gid=2000 -t functionfs bulk2 /dev/usb-ffs/bulk2

            cfg_str="${cfg_str}+BULK3"
            mkdir -p /dev/usb-ffs/bulk3
            func=functions/ffs.bulk3
            mkdir -p "${func}"
            ln -sf "${func}" "${cfg}"
            mount -o mode=0777,uid=2000,gid=2000 -t functionfs bulk3 /dev/usb-ffs/bulk3
        fi

        mkdir -p "${cfg}/strings/0x409"
        echo "${cfg_str:1}" > "${cfg}/strings/0x409/configuration"
    # cd -

fi

if [ ${enable_bulk} -eq 1 ]; then
    if [ ! -f ${startup_bulk_exe} ]; then
        cd ${startup_bulk_dir}
            make && ( $? != 0 ) && ( exit 1 )
            cp startup_bulk ${startup_bulk_exe}
            make clean
        cd -
    fi

    ${startup_bulk_exe} /dev/usb-ffs/bulk1 &
    sleep 1
    ${startup_bulk_exe} /dev/usb-ffs/bulk2 &
    sleep 1
    ${startup_bulk_exe} /dev/usb-ffs/bulk3 &
    sleep 1
fi

    udevadm settle -t 5 || :
    ls /sys/class/udc > UDC

if [ ${enable_rndis} -eq 1 ]; then
    /sbin/brctl addbr pi4br0
    /sbin/ifconfig pi4br0 ${net_ip} netmask ${net_mask} up

    /sbin/brctl addif pi4br0 usb0
    /sbin/ifconfig usb0 down
    /sbin/ifconfig usb0 up
fi
exit 0