#!/bin/sh

# List of services enabled by default (in case of absence of xenstore entry)
DEFAULT_ENABLED_NETVM="network-manager qubes-network qubes-update-check"
DEFAULT_ENABLED_PROXYVM="meminfo-writer qubes-network qubes-firewall qubes-netwatcher qubes-update-check"
DEFAULT_ENABLED_APPVM="meminfo-writer cups qubes-update-check"
DEFAULT_ENABLED_TEMPLATEVM=$DEFAULT_ENABLED_APPVM
DEFAULT_ENABLED="meminfo-writer"

XS_READ=/usr/bin/xenstore-read
XS_LS=/usr/bin/xenstore-ls

read_service() {
    $XS_READ qubes-service/$1 2> /dev/null
}

# Wait for evtchn initialization
while [ ! -e /proc/xen/xenbus ]; do
  sleep 0.1
done

mkdir -p /var/run/qubes
mkdir -p /var/run/qubes-service
mkdir -p /var/run/xen-hotplug

# Set permissions to /proc/xen/xenbus, so normal user can use xenstore-read
chmod 666 /proc/xen/xenbus

# Set default services depending on VM type
TYPE=`$XS_READ qubes_vm_type 2> /dev/null`
[ "$TYPE" == "AppVM" ] && DEFAULT_ENABLED=$DEFAULT_ENABLED_APPVM
[ "$TYPE" == "NetVM" ] && DEFAULT_ENABLED=$DEFAULT_ENABLED_NETVM
[ "$TYPE" == "ProxyVM" ] && DEFAULT_ENABLED=$DEFAULT_ENABLED_PROXYVM
[ "$TYPE" == "TemplateVM" ] && DEFAULT_ENABLED=$DEFAULT_ENABLED_TEMPLATEVM

# Enable default services
for srv in $DEFAULT_ENABLED; do
    touch /var/run/qubes-service/$srv
done

# Enable services
for srv in `$XS_LS qubes-service 2>/dev/null |grep ' = "1"'|cut -f 1 -d ' '`; do
    touch /var/run/qubes-service/$srv
done

# Disable services
for srv in `$XS_LS qubes-service 2>/dev/null |grep ' = "0"'|cut -f 1 -d ' '`; do
    rm -f /var/run/qubes-service/$srv
done

# Set the hostname
name=`$XS_READ name`
if [ -n "$name" ]; then
    hostname $name
    sed -i "s/^\(127\.0\.0\.1 .*\) \($name \)\?\(.*\)/\1\2 $name/" /etc/hosts
fi

timezone=`$XS_READ qubes-timezone 2> /dev/null`
if [ -n "$timezone" ]; then
    ln -f /usr/share/zoneinfo/$timezone /etc/localtime
    echo "# Clock configuration autogenerated based on Qubes dom0 settings" > /etc/sysconfig/clock
    echo "ZONE=\"$timezone\"" >> /etc/sysconfig/clock
fi

# Prepare environment for other services
echo > /var/run/qubes-service-environment

debug_mode=`$XS_READ qubes-debug-mode 2> /dev/null`
if [ -n "$debug_mode" -a "$debug_mode" -gt 0 ]; then
    echo "GUI_OPTS=-vv" >> /var/run/qubes-service-environment
fi
