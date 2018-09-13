set -e

CWD=`pwd`
MY_REPO_PATH="http://www.tbi.univie.ac.at/~ronny/alarm/"
MY_CHROOT_DIR=/tmp/arfs
PROGRESS_PID=
LOGFILE="${CWD}/archlinux-install.log"
spin='-\|/'

function progress () {
  arg=$1
  echo -n "$arg   "
  while true
  do
    i=$(( (i+1) %4 ))
    printf "\r$arg   ${spin:$i:1}"
    sleep .1
  done
}

function start_progress () {
  # Start it in the background
  progress "$1" &
  # Save progress() PID
  PROGRESS_PID=$!
  disown
}

function end_progress () {

# Kill progress
kill ${PROGRESS_PID} >/dev/null  2>&1
echo -n " ...done."
echo
}

#
# Note, this function removes the script after execution
#
function exec_in_chroot () {

  script=$1

  if [ -f ${MY_CHROOT_DIR}/${script} ] ; then
    chmod a+x ${MY_CHROOT_DIR}/${script}
    chroot ${MY_CHROOT_DIR} /bin/bash -c /${script} >> ${LOGFILE} 2>&1
    rm ${MY_CHROOT_DIR}/${script}
  fi
}


function setup_chroot () {

  mount -o bind /proc ${MY_CHROOT_DIR}/proc
  mount -o bind /dev ${MY_CHROOT_DIR}/dev
  mount -o bind /dev/pts ${MY_CHROOT_DIR}/dev/pts
  mount -o bind /sys ${MY_CHROOT_DIR}/sys

}


function unset_chroot () {

  if [ "x${PROGRESS_PID}" != "x" ]
  then
    end_progress
  fi

  umount ${MY_CHROOT_DIR}/proc
  umount ${MY_CHROOT_DIR}/dev
  umount ${MY_CHROOT_DIR}/dev/pts
  umount ${MY_CHROOT_DIR}/sys

}

trap unset_chroot EXIT

function copy_chros_files () {

  start_progress "Copying files from ChromeOS to ArchLinuxARM rootdir"

  mkdir -p ${MY_CHROOT_DIR}/run/resolvconf
  cp /etc/resolv.conf ${MY_CHROOT_DIR}/run/resolvconf/
  ln -s -f /run/resolvconf/resolv.conf ${MY_CHROOT_DIR}/etc/resolv.conf
  echo alarm > ${MY_CHROOT_DIR}/etc/hostname
  echo -e "\n127.0.1.1\tlocalhost.localdomain\tlocalhost\talarm" >> ${MY_CHROOT_DIR}/etc/hosts

  KERN_VER=`uname -r`
  #mkdir -p ${MY_CHROOT_DIR}/lib/modules/$KERN_VER/
  #cp -ar /lib/modules/$KERN_VER/* ${MY_CHROOT_DIR}/lib/modules/$KERN_VER/
  mkdir -p ${MY_CHROOT_DIR}/lib/firmware/
  cp -ar /lib/firmware/* ${MY_CHROOT_DIR}/lib/firmware/

  # remove tegra_lp0_resume firmware since it is owned by latest
  # linux-nyan kernel package
  #rm ${MY_CHROOT_DIR}/lib/firmware/tegra12x/tegra_lp0_resume.fw

  end_progress
}

function install_dev_tools () {

start_progress "Installing development base packages"

#
# Add some development tools and put the alarm user into the
# wheel group. Furthermore, grant ALL privileges via sudo to users
# that belong to the wheel group
#
cat > ${MY_CHROOT_DIR}/install-develbase.sh << EOF
pacman-key --init
pacman-key --populate
pacman -Syyu --needed --noconfirm sudo wget dialog base-devel devtools vim rsync git vboot-utils
usermod -aG wheel alarm
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
EOF

exec_in_chroot install-develbase.sh

end_progress
}

function install_xbase () {

start_progress "Installing X-server basics"

cat > ${MY_CHROOT_DIR}/install-xbase.sh <<EOF

pacman -Syy --needed --noconfirm \
        iw networkmanager network-manager-applet \
        lightdm lightdm-gtk-greeter \
        chromium \
        xorg-server xorg-apps xf86-input-synaptics \
        xorg-twm xorg-xclock xterm xorg-xinit \
        xorg-server-common xorg-server-xvfb \
        xf86-input-mouse xf86-input-keyboard \
        xf86-input-evdev xf86-input-synaptics xf86-video-fbdev
systemctl enable NetworkManager
systemctl enable lightdm
EOF

exec_in_chroot install-xbase.sh

end_progress

}


function install_xfce4 () {

start_progress "Installing XFCE4"

# add .xinitrc to /etc/skel that defaults to xfce4 session
cat > ${MY_CHROOT_DIR}/etc/skel/.xinitrc << EOF
#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x \"\$f\" ] && . \"\$f\"
  done
  unset f
fi

# exec gnome-session
# exec startkde
exec startxfce4
# ...or the Window Manager of your choice
EOF

cat > ${MY_CHROOT_DIR}/install-xfce4.sh << EOF

pacman -Syy --needed --noconfirm  xfce4 xfce4-goodies
# copy .xinitrc to already existing home of user 'alarm'
cp /etc/skel/.xinitrc /home/alarm/.xinitrc
cp /etc/skel/.xinitrc /home/alarm/.xprofile
sed -i 's/exec startxfce4/# exec startxfce4/' /home/alarm/.xprofile
chown alarm:users /home/alarm/.xinitrc
chown alarm:users /home/alarm/.xprofile
EOF

exec_in_chroot install-xfce4.sh

end_progress

}


function install_kernel () {

#start_progress "Installing kernel"

cat > ${MY_CHROOT_DIR}/install-kernel.sh << EOF

#pacman -R --noconfirm linux-armv7
#pacman -Syy --needed --noconfirm linux-armv7-rc linux-armv7-rc-chromebook
pacman -Syy --needed --noconfirm linux-armv7 linux-armv7-chromebook
dd if=/boot/vmlinux.kpart of=${target_kern}
echo elan_i2c > /etc/modules-load.d/elan_touchpad.conf
echo bq24735_charger > /etc/modules-load.d/bq2473_charger.conf

EOF

chmod a+x /tmp/arfs/install-kernel.sh
chroot /tmp/arfs /bin/bash -c /install-kernel.sh
rm /tmp/arfs/install-kernel.sh


}


function tweak_misc_stuff () {

# hack for removing uap0 device on startup (avoid freeze)
echo 'install mwifiex_sdio /sbin/modprobe --ignore-install mwifiex_sdio && sleep 1 && iw dev uap0 del' > ${MY_CHROOT_DIR}/etc/modprobe.d/mwifiex.conf

cat > ${MY_CHROOT_DIR}/etc/udev/rules.d/99-tegra-lid-switch.rules <<EOF
ACTION=="remove", GOTO="tegra_lid_switch_end"

SUBSYSTEM=="input", KERNEL=="event*", SUBSYSTEMS=="platform", KERNELS=="gpio-keys.4", TAG+="power-switch"

LABEL="tegra_lid_switch_end"
EOF

}

function install_misc_utils () {

start_progress "Installing some more utilities"

cat > ${MY_CHROOT_DIR}/install-utils.sh <<EOF
pacman -Syy --needed --noconfirm  sshfs screen file-roller
EOF

exec_in_chroot install-utils.sh

end_progress

}


function install_sound () {

start_progress "Installing sound (alsa/pulseaudio)"

cat > ${MY_CHROOT_DIR}/install-sound.sh <<EOF

pacman -Syy --needed --noconfirm \
        alsa-lib alsa-utils alsa-tools alsa-oss alsa-firmware alsa-plugins \
        pulseaudio pulseaudio-alsa
EOF

exec_in_chroot install-sound.sh

end_progress

}

echo "" > $LOGFILE

# fw_type will always be developer for Mario.
# Alex and ZGB need the developer BIOS installed though.
fw_type="`crossystem mainfw_type`"
if [ ! "$fw_type" = "developer" ]
  then
    echo -e "\nYou're Chromebook is not running a developer BIOS!"
    echo -e "You need to run:"
    echo -e ""
    echo -e "sudo chromeos-firmwareupdate --mode=todev"
    echo -e ""
    echo -e "and then re-run this script."
    exit
fi

powerd_status="`initctl status powerd`"
if [ ! "$powerd_status" = "powerd stop/waiting" ]
then
  echo -e "Stopping powerd to keep display from timing out..."
  initctl stop powerd
fi

#setterm -blank 0

echo ""
echo "WARNING! This script will install binary packages from an unofficial source!"
echo ""
echo "If you don't trust me (Ronny Lorenz a.k.a. RaumZeit) press CTRL+C to quit"
echo "(see https://github.com/RaumZeit/LinuxOnAcerCB5-311 for further details)"
echo ""
read -p "Press [Enter] to proceed installation of ArchLinuxARM"

if [ "$1" != "" ]; then
  target_disk=$1
  echo "Got ${target_disk} as target drive"
  echo ""
  echo "WARNING! All data on this device will be wiped out! Continue at your own risk!"
  echo ""
  read -p "Press [Enter] to install ArchLinuxARM on ${target_disk} or CTRL+C to quit"

  kern_part=1
  root_part=2
  ext_size="`blockdev --getsz ${target_disk}`"
  aroot_size=$((ext_size - 65600 - 33))
  cgpt create ${target_disk}
  cgpt add -i ${kern_part} -b 64 -s 32768 -S 1 -P 5 -l KERN-A -t "kernel" ${target_disk}
  cgpt add -i ${root_part} -b 65600 -s $aroot_size -l ROOT-A -t "rootfs" ${target_disk}
  sync
  blockdev --rereadpt ${target_disk}
  crossystem dev_boot_usb=1
else
  target_disk="`rootdev -d -s`"
  kern_part=6
  root_part=7
  # Do partitioning (if we haven't already)
  ckern_size="`cgpt show -i ${kern_part} -n -s -q ${target_disk}`"
  croot_size="`cgpt show -i ${root_part} -n -s -q ${target_disk}`"
  state_size="`cgpt show -i 1 -n -s -q ${target_disk}`"

  max_archlinux_size=$(($state_size/1024/1024/2))
  rec_archlinux_size=$(($max_archlinux_size - 1))
  # If KERN-C and ROOT-C are one, we partition, otherwise assume they're what they need to be...
  if [ "$ckern_size" =  "1" -o "$croot_size" = "1" ]
  then
    while :
    do
      read -p "Enter the size in gigabytes you want to reserve for ArchLinux. Acceptable range is 5 to $max_archlinux_size  but $rec_archlinux_size is the recommended maximum: " archlinux_size
      if [ ! $archlinux_size -ne 0 2>/dev/null ]
      then
        echo -e "\n\nNumbers only please...\n\n"
        continue
      fi
      if [ $archlinux_size -lt 5 -o $archlinux_size -gt $max_archlinux_size ]
      then
        echo -e "\n\nThat number is out of range. Enter a number 5 through $max_archlinux_size\n\n"
        continue
      fi
      break
    done
    # We've got our size in GB for ROOT-C so do the math...

    #calculate sector size for rootc
    rootc_size=$(($archlinux_size*1024*1024*2))

    #kernc is always 16mb
    kernc_size=32768

    #new stateful size with rootc and kernc subtracted from original
    stateful_size=$(($state_size - $rootc_size - $kernc_size))

    #start stateful at the same spot it currently starts at
    stateful_start="`cgpt show -i 1 -n -b -q ${target_disk}`"

    #start kernc at stateful start plus stateful size
    kernc_start=$(($stateful_start + $stateful_size))

    #start rootc at kernc start plus kernc size
    rootc_start=$(($kernc_start + $kernc_size))

    #Do the real work

    echo -e "\n\nModifying partition table to make room for ArchLinux."
    echo -e "Your Chromebook will reboot, wipe your data and then"
    echo -e "you should re-run this script..."
    umount -l /mnt/stateful_partition

    # stateful first
    cgpt add -i 1 -b $stateful_start -s $stateful_size -l STATE ${target_disk}

    # now kernc
    cgpt add -i ${kern_part} -b $kernc_start -s $kernc_size -l KERN-C ${target_disk}

    # finally rootc
    cgpt add -i ${root_part} -b $rootc_start -s $rootc_size -l ROOT-C ${target_disk}

    reboot
    exit
  fi
fi

# hwid lets us know if this is a Mario (Cr-48), Alex (Samsung Series 5), ZGB (Acer), etc
hwid="`crossystem hwid`"

chromebook_arch="`uname -m`"
archlinux_arch="armv7"
archlinux_version="latest"

echo -e "\nChrome device model is: $hwid\n"

echo -e "Installing ArchLinuxARM ${archlinux_version}\n"

echo -e "Kernel Arch is: $chromebook_arch  Installing ArchLinuxARM Arch: ${archlinux_arch}\n"

read -p "Press [Enter] to continue..."

if [ ! -d /mnt/stateful_partition/archlinux ]
then
  mkdir /mnt/stateful_partition/archlinux
fi

cd /mnt/stateful_partition/archlinux

if [[ "${target_disk}" =~ "mmcblk" ]]
then
  target_rootfs="${target_disk}p${root_part}"
  target_kern="${target_disk}p${kern_part}"
else
  target_rootfs="${target_disk}${root_part}"
  target_kern="${target_disk}${kern_part}"
fi

echo "Target Kernel Partition: $target_kern  Target Root FS: ${target_rootfs}"

if mount|grep ${target_rootfs}
then
  echo "Refusing to continue since ${target_rootfs} is formatted and mounted. Try rebooting"
  exit
fi

mkfs.ext4 ${target_rootfs}

if [ ! -d /tmp/arfs ]
then
  mkdir /tmp/arfs
fi
mount -t ext4 ${target_rootfs} /tmp/arfs

tar_file="http://archlinuxarm.org/os/ArchLinuxARM-${archlinux_arch}-${archlinux_version}.tar.gz"

start_progress "Downloading and extracting ArchLinuxARM rootfs"

curl -s -L --output - $tar_file | tar xzvvp -C /tmp/arfs/ >> ${LOGFILE} 2>&1

end_progress

setup_chroot

copy_chros_files

install_dev_tools

install_xbase

install_xfce4

install_sound

install_kernel

install_misc_utils

#tweak_misc_stuff

#Set ArchLinuxARM kernel partition as top priority for next boot (and next boot only)
cgpt add -i ${kern_part} -P 5 -T 1 ${target_disk}

echo -e "

Installation seems to be complete. If ArchLinux fails when you reboot,
power off your Chrome OS device and then turn it back on. You'll be back
in Chrome OS. If you're happy with ArchLinuxARM when you reboot be sure to run:

sudo cgpt add -i ${kern_part} -P 5 -S 1 ${target_disk}

To make it the default boot option. The ArchLinuxARM login is:

Username:  alarm
Password:  alarm

Root access can either be gained via sudo, or the root user:

Username:  root
Password:  root

We're now ready to start ArchLinuxARM!
"

read -p "Press [Enter] to reboot..."

reboot
