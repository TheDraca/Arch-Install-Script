#!/bin/bash
loadkeys uk
echo "######Arch Linux Install Script ~ EPQ 2017######"
echo "Testing for internet connection"

ping -c2 www.google.co.uk

if [ $? -eq 0 ]
then
  echo "Connected to the web, ready to go"
else
  echo "Not connected to the web, exiting"
  echo "Use wifi-menu to connect to a wireless network then re-run this script"
  exit
fi

### Check for UEFI or BIOS ###
if [ -d /sys/firmware/efi/efivars ]
then
  echo "UEFI system detected!!"
  InstallType="UEFI"

else
  echo "BIOS system detected!"
  echo "BIOS install is not reccomended! If your system supports UEFI you should boot via UEFI instead"
  echo "1. Poweroff now"
  echo "2. Continue with unrecommened BIOS install"
  function InstallBIOSWarning {
    read -p "Enter selection number: " InstallBIOSWarningSelection
    case ${InstallBIOSWarningSelection} in
      1) poweroff;;
      2) InstallType="BIOS";;
      *) echo "Invalid selection"; InstallBootSelector;;
    esac
  }
  InstallBIOSWarning
fi

## Ensure time is correct##
timedatectl set-ntp true

### Select which drive to install to! ###

echo "Which Drive are we installing to?"
lsblk

read -p 'Enter Drive name (Usually sda): ' InstallDriveName
echo "Installing to ${InstallDriveName}"

mkdir -p /mnt
InstallParted="parted -s /dev/${InstallDriveName}"


### Prompt for desktop enviroment choice ###
function InstallDesktopEnviromentPrompt {
  echo ""
  echo "Which desktop enviroment do you want to install?"
  echo "1) KDE Plasma"
  echo "2) Gnome"
  echo "3) Cinnamon"
  echo "4) XFCE"
  echo "0) None"
  read -p "Enter selection:  " InstallDesktopEnviromentSelection
  case ${InstallDesktopEnviromentSelection} in
    1) InstallDesktopEnviroment="plasma";;
    2) InstallDesktopEnviroment="gnome";;
    3) InstallDesktopEnviroment="cinnamon";;
    4) InstallDesktopEnviroment="xfce";;
    0) InstallDesktopEnviroment="none";;
    *) echo "Invalid selection";  InstallDesktopEnviromentPrompt;;
  esac
}
InstallDesktopEnviromentPrompt

### Prompt for Desktop manager choice ###
function InstallDesktopManagerPrompt {
  echo ""
  echo "Which desktop manager do you want to install?"
  echo "1) GDM"
  echo "2) LightDM"
  echo "0) None"
  read -p "Enter selection:  " InstallDesktopManagerSelection
  case ${InstallDesktopManagerSelection} in
    1) InstallDesktopManager="gdm";;
    2) InstallDesktopManager="lightdm";;
    0) InstallDesktopManager="none";;
    *) echo "Invalid selection";  InstallDesktopManagerPrompt;;
  esac
}
InstallDesktopManagerPrompt




### User creation info ###
function InstallCreateUser {
  read -p "Enter a your username (MUST be all letters and lowercase!): " InstallUsername
  read -s -p "Enter a password for ${InstallUsername}: " InstallUserPassword
  echo " "
  read -s -p "Confirm password for ${InstallUsername}: " InstallUserPassword2
  echo " "
  if [[ ${InstallUserPassword} = ${InstallUserPassword2} ]]
  then
    echo "User ${InstallUsername} will be created! Remember your login details!"
  else
    echo "Passwords did not match!!"
    InstallCreateUser
  fi
}
InstallCreateUser

function InstallCreateRootPassword {
  echo ""
  echo "Set a password for the root user (DO NOT FORGET THIS!)"
  read -s -p "Enter a password for root: " InstallRootPassword
  echo " "
  read -s -p "Confirm password for root: " InstallRootPassword2
  echo " "
  if [[ ${InstallRootPassword} = ${InstallRootPassword2} ]]
  then
    echo "Root password set"
  else
    echo "Passwords did not match!!"
    InstallCreateRootPassword
  fi
}
InstallCreateRootPassword


read -p "Enter a hostname: " InstallHostname


function InstallUEFI {

  ${InstallParted} mklabel gpt
  ${InstallParted} mkpart ESP fat32 1MiB 513MiB
  ${InstallParted} set 1 boot on
  ${InstallParted} mkpart primary linux-swap 513MiB 4.5GiB
  ${InstallParted} mkpart primary ext4 4.5GiB 100%


  echo "New partition structure \n"
  lsblk

  mkswap /dev/${InstallDriveName}2
  swapon /dev/${InstallDriveName}2

  mkfs.fat -F32 /dev/${InstallDriveName}1

  mkfs.ext4 /dev/${InstallDriveName}3

  mount /dev/${InstallDriveName}3 /mnt

  mkdir -p /mnt/boot
  mount /dev/${InstallDriveName}1 /mnt/boot

}

function InstallBIOS {
  ${InstallParted} mklabel msdos
  ${InstallParted} mkpart primary linux-swap 1MiB 4GiB
  ${InstallParted} mkpart primary ext4 4GiB 100%
  ${InstallParted} set 2 boot on

  echo "New partition structure:"
  lsblk

  mkswap /dev/${InstallDriveName}1
  swapon /dev/${InstallDriveName}1
  mkfs.ext4 /dev/${InstallDriveName}2

  mount /dev/${InstallDriveName}2 /mnt

}

### Create + Format paritions base on UEFI or BIOS ###
if [[ ${InstallType} = "UEFI" ]]
then
  echo "Installing in UEFI mode! :)"
  InstallUEFI
elif [[ ${InstallType} = "BIOS" ]]
then
  echo "Installing in BIOS mode :()"
  InstallBIOS
else
  echo "No Install Type"
  exit
fi

### Set mirror to UK based one ###

InstallMirror='http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch'

echo -e "Server = ${InstallMirror}\n$(cat /etc/pacman.d/mirrorlist)" > /etc/pacman.d/mirrorlist

echo "Mirror changed to UK based one"

### Install base system ###
pacstrap -i /mnt base linux linux-firmware --noconfirm

genfstab -U /mnt > /mnt/etc/fstab

echo "Based system installed"

### Set Lang + Timezone###
arch-chroot /mnt /bin/bash <<EOF
sed -i '/en_GB.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
echo LANG=en_GB.UTF-8 > /etc/locale.conf
export LANG=en_GB.UTF-8
(echo '7'; echo '8'; echo '1') | tzselect
ln -sf /usr/share/zoneinfo/Europe/London  /etc/localtime
hwclock --systohc --utc
locale-gen

EOF


### Set hostname + root password of users choice ###
arch-chroot /mnt /bin/bash <<EOF
echo ${InstallHostname} > /etc/hostname
echo "127.0.1.1 ${InstallHostname}.local ${InstallHostname}" >> /etc/hosts
echo "root:${InstallRootPassword}" | chpasswd
EOF

###Setup bootloader###
if [ ${InstallType} == "UEFI" ]
then
  echo "Installing GRUB for UEFI!"
  arch-chroot /mnt /bin/bash <<EOF
  pacman -Sy grub os-prober efibootmgr --noconfirm
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
EOF
elif [ ${InstallType} == "BIOS" ]
then
  echo "Installing GRUB for BIOS!"
  arch-chroot /mnt /bin/bash <<EOF
  pacman -Sy grub os-prober --noconfirm
  grub-install --recheck --target=i386-pc /dev/${InstallDriveName}
EOF
else
  exit
fi
arch-chroot /mnt /bin/bash <<EOF
grub-mkconfig -o boot/grub/grub.cfg
EOF
echo "Grub Installed"


###Install network manager###
arch-chroot /mnt /bin/bash <<EOF
pacman -S networkmanager --noconfirm
systemctl disable dhcpcd
systemctl enable NetworkManager
EOF


###Install sudo and other bits I like###
arch-chroot /mnt /bin/bash <<EOF
pacman -S sudo bash-completion nano git wget gparted ntfs-3g exfatprogs gpart --noconfirm
EOF

###Create user using preset info###
arch-chroot /mnt /bin/bash <<EOF
useradd -m -g users -G wheel -s /bin/bash ${InstallUsername}
echo "${InstallUsername}:${InstallUserPassword}" | chpasswd
echo '${InstallUsername} ALL=(ALL:ALL) ALL' >> /etc/sudoers
EOF

###Install display server###
function InstallXORG {
arch-chroot /mnt /bin/bash <<EOF
pacman -S xorg-server --noconfirm
pacman -S xf86-video-intel --noconfirm
pacman -S xf86-input-synaptics --noconfirm
EOF
}

###Install Desktop Eviroment###
if [ ${InstallDesktopEnviroment} == "plasma" ]
then
  InstallXORG
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S plasma --noconfirm
EOF
elif [ ${InstallDesktopEnviroment} == "gnome" ]
then
  InstallXORG
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S gnome --noconfirm
EOF
elif [ ${InstallDesktopEnviroment} == "cinnamon" ]
then
  InstallXORG
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S cinnamon --noconfirm
EOF
elif [ ${InstallDesktopEnviroment} == "xfce" ]
then
  InstallXORG
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S xfce4 --noconfirm
EOF
else
  echo "No Desktop enviroment will be installed"
fi

###Install Desktop Manager###
if [ ${InstallDesktopManager} == "gdm" ]
then
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S gdm --noconfirm
  systemctl enable gdm
EOF
elif [ ${InstallDesktopManager} == "lightdm" ]
then
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S lightdm lightdm-gtk-greeter --noconfirm
  systemctl enable lightdm
EOF
else
  echo "No Dekstop Manager installed"
fi

###Enable Multilibs###
arch-chroot /mnt /bin/bash <<EOF
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy
EOF

###Unmount System###
umount -R /mnt
###Prompt for shutdown###
read -p 'Install complete, press enter to shutdown! You may want to run "localectl set-keymap uk" once booted!'
shutdown now
