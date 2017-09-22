#!/bin/bash -v

set -ex

if [ "x$REJECT_OUTBOUND" == "xYES" ]; then
PNDA_MIRROR_IP=$(echo $PNDA_MIRROR | awk -F'[/:]' '/http:\/\//{print $4}')

# Log the global scope IP connection.
cat > /etc/rsyslog.d/10-iptables.conf <<EOF
:msg,contains,"[ipreject] " /var/log/iptables.log
STOP
EOF
sudo service rsyslog restart
iptables -N LOGGING
iptables -A OUTPUT -j LOGGING
## Accept all local scope IP packets.
  ip address show  | awk '/inet /{print $2}' | while IFS= read line; do \
iptables -A LOGGING -d  $line -j ACCEPT
  done
## Log and reject all the remaining IP connections.
iptables -A LOGGING -j LOG --log-prefix "[ipreject] " --log-level 7 -m state --state NEW
iptables -A LOGGING -d  $PNDA_MIRROR_IP/32 -j ACCEPT # PNDA mirror
if [ "x$CLIENT_IP" != "x" ]; then
iptables -A LOGGING -d  $CLIENT_IP/32 -j ACCEPT # PNDA client
fi
if [ "x$NTP_SERVERS" != "x" ]; then
iptables -A LOGGING -d  $NTP_SERVERS -j ACCEPT # NTP server
fi
iptables -A LOGGING -d  10.0.0.0/16 -j ACCEPT      # PNDA network
iptables -A LOGGING -j REJECT
fi

DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)
if [ "x$DISTRO" == "xubuntu" ]; then
  export DEBIAN_FRONTEND=noninteractive
  # give the local mirror the first priority 
  sed -i "1ideb $PNDA_MIRROR/mirror_deb/ ./" /etc/apt/sources.list
  wget -O - $PNDA_MIRROR/mirror_deb/pnda.gpg.key | apt-key add -
  apt-get update

elif [ "x$DISTRO" == "xrhel" ]; then
  mkdir -p /etc/yum.repos.d.backup/
  mv /etc/yum.repos.d/* /etc/yum.repos.d.backup/
  yum-config-manager --add-repo $PNDA_MIRROR/mirror_rpm

  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-redhat-release
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-mysql
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-cloudera
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-EPEL-7
  rpm --import $PNDA_MIRROR/mirror_rpm/SALTSTACK-GPG-KEY.pub
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-CentOS-7
  rpm --import $PNDA_MIRROR/mirror_rpm/RPM-GPG-KEY-Jenkins
fi
