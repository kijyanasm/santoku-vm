#!/bin/bash

# Install the VirtualBox guest additions if they aren't already installed.
if [ ! -d /opt/VBoxGuestAdditions-4.3.4/ ]; then
    # Update remote package metadata.  'apt-get update' is idempotent.
    apt-get update -q

    # Kernel Headers and dkms are required to build the vbox guest kernel
    # modules.
    apt-get install -q -y linux-headers-generic-lts-raring dkms

    echo 'Downloading VBox Guest Additions...'
    wget -cq http://dlc.sun.com.edgesuite.net/virtualbox/4.3.4/VBoxGuestAdditions_4.3.4.iso
    echo "f120793fa35050a8280eacf9c930cf8d9b88795161520f6515c0cc5edda2fe8a  VBoxGuestAdditions_4.3.4.iso" | sha256sum --check || exit 1

    mount -o loop,ro /home/vagrant/VBoxGuestAdditions_4.3.4.iso /mnt
    /mnt/VBoxLinuxAdditions.run --nox11
    umount /mnt
fi

# The username to add to the docker group will be passed as the first argument
# to the script.  If nothing is passed, default to "vagrant".
user="$1"
if [ -z "$user" ]; then
    user=vagrant
fi

# Adding an apt gpg key is idempotent.
wget -q -O - https://get.docker.io/gpg | apt-key add -
wget -q -O - http://packages.santoku-linux.com/santoku.key | apt-key add -

# Creating the docker.list file is idempotent, but it may overwrite desired
# settings if it already exists.  This could be solved with md5sum but it
# doesn't seem worth it.
echo 'deb http://get.docker.io/ubuntu docker main' > \
    /etc/apt/sources.list.d/docker.list

# Creating the santoku.list file is idempotent 
echo 'deb http://packages.santoku-linux.com/ubuntu precise main' > \
    /etc/apt/sources.list.d/santoku.list

rm -r -f /etc/default/docker

# Update remote package metadata.  'apt-get update' is idempotent.
apt-get update -q

apt-get upgrade -q -y

# Install docker.  'apt-get install' is idempotent.
apt-get install -q -y lxc-docker

# Install other needed packages. 'apt-get install' is idempotent.
apt-get install -q -y jq curl git python python-pip unzip
apt-get install -q -y libc6-i386 lib32stdc++6 lib32gcc1 lib32ncurses5
apt-get install -q -y default-jdk
apt-get install -q -y lubuntu-desktop
apt-get install -q -y --force-yes santoku

if [ ! -e /root/android_adt.txt ]; then
	echo "Installing Android ADT Bundle with SDK and Eclipse..."
	cd /tmp
	curl -O http://dl.google.com/android/adt/adt-bundle-linux-x86_64-20130729.zip
	unzip /tmp/adt-bundle-linux-x86_64-20130729.zip >/dev/null 2>&1
	mv /tmp/adt-bundle-linux-x86_64-20130729 /usr/local/android/
	rm -rf /tmp/adt-bundle-linux-x86_64-20130729.zip
	touch /root/android_adt.txt
fi

if [ ! -e /root/android_ndk.txt ]; then
	echo "Installing Android NDK..."
	cd /tmp
	curl -O http://dl.google.com/android/ndk/android-ndk-r9-linux-x86_64.tar.bz2
	tar -jxf /tmp/android-ndk-r9-linux-x86_64.tar.bz2 >/dev/null 2>&1
	mv /tmp/android-ndk-r9 /usr/local/android/ndk
	rm -rf /tmp/android-ndk-r9-linux-x86_64.tar.bz2
	touch /root/android_ndk.txt
fi

# Idempotent with -p option
mkdir -p /usr/local/android/sdk/add-ons

chmod -R 755 /usr/local/android

ln -s /usr/local/android/sdk/tools/android /usr/bin/android
ln -s /usr/local/android/sdk/platform-tools/adb /usr/bin/adb

echo "Updating ANDROID_HOME..."
cd ~/
cat << End >> .profile
export ANDROID_HOME="/usr/local/android/sdk"
export PATH=$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH
End

echo "Adding USB device driver information..."
echo "For more detail see http://developer.android.com/tools/device.html"

cp /vagrant/51-android.rules /etc/udev/rules.d
chmod a+r /etc/udev/rules.d/51-android.rules

service udev restart

android update adb
adb kill-server
adb start-server

usermod -a -G docker "$user"

tmp=`mktemp -q` && {
    # Only install the backport kernel, don't bother upgrading if the backport is
    # already installed.  We want parse the output of apt so we need to save it
    # with 'tee'.  NOTE: The installation of the kernel will trigger dkms to
    # install vboxguest if needed.
    apt-get install -q -y --no-upgrade linux-image-generic-lts-raring | \
        tee "$tmp"

    # Parse the number of installed packages from the output
    NUM_INST=`awk '$2 == "upgraded," && $4 == "newly" { print $3 }' "$tmp"`
    rm "$tmp"
}

# If the number of installed packages is greater than 0, we want to reboot (the
# backport kernel was installed but is not running).
if [ "$NUM_INST" -gt 0 ];
then
    echo " "
    echo " "
    echo " "
    echo "[ Next Steps ]================================================================"
    echo " "
    echo "1. Manually setup a USB connection for your Android device to the new VM"
    echo " "
    echo "	If using VMware Fusion (for example, will be similar for VirtualBox):"
    echo "  	1. Plug your android device hardware into the computers USB port"
    echo "  	2. Open the 'Virtual Machine Library'"
    echo "  	3. Select the VM, e.g. 'android-vm: default', right-click and choose"
    echo " 		   'Settings...'"
    echo "  	4. Select 'USB & Bluetooth', check the box next to your device and set"
    echo " 		   the 'Plug In Action' to 'Connect to Linux'"
    echo "  	5. Plug the device into the USB port and verify that it appears when "
    echo "         you run 'lsusb' from the command line"
    echo " "
    echo "2. Your device should appear when running 'lsusb' enabling you to use adb, e.g."
    echo " "
    echo "		$ adb devices"
    echo "			ex. output,"
    echo " 		       List of devices attached"
    echo " 		       007jbmi6          device"
    echo " "
    echo "		$ adb shell"
    echo " 		    i.e. to log into the device (be sure to enable USB debugging on the device)"
    echo " "
    echo "See the included README.md for more detail on how to run and work with this VM."

    echo "Rebooting down to activate new kernel."
    echo "/vagrant will not be mounted.  Use 'vagrant halt' followed by"
    echo "'vagrant up' to ensure /vagrant is mounted."
    shutdown -r now
fi

