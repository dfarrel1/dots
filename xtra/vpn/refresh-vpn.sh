#!/bin/bash
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

### Need to get config file
conf_file=$(cd ~; pwd)/Downloads/client.ovpn

[[ ! $(grep "openvpn.log" ${conf_file}) ]] \
&& echo "log /var/log/openvpn.log" >> ${conf_file}

auth_file="/usr/local/etc/openvpn/vpnclient.auth"
auth_user_pass_file="/usr/local/etc/openvpn/custom/auth_user_pass.txt"
[[ ! -d /usr/local/etc/openvpn/custom/ ]] && mkdir -p /usr/local/etc/openvpn/custom/
touch ${auth_user_pass_file}


[[ ! $(grep "askpass" ${conf_file}) ]] \
&& echo """
# daemon
# askpass ${auth_file}
auth-user-pass ${auth_user_pass_file}
# auth-nocache
""" >> ${conf_file}

### Set to appropriate user (bc running from root)
pass_user="dene-latch"
echo `security find-generic-password -a ${pass_user} -s openvpn -w` > ${auth_file} \
&& chmod 600 ${auth_file}

echo `security find-generic-password -a ${pass_user} -s openvpn-user -w` > ${auth_user_pass_file} \
&& echo `security find-generic-password -a ${pass_user} -s openvpn -w` >> ${auth_user_pass_file} \
&& chmod 600 ${auth_user_pass_file}

[[ -f ${conf_file} ]] &&  cp ${conf_file} /usr/local/etc/openvpn/client.ovpn

cp ${HERE}/openvpn.conf /etc/newsyslog.d/
cp ${HERE}/openvpn.latch.client.plist /Library/LaunchDaemons/
[[ ! -d /var/log/openvpn/ ]] && mkdir /var/log/openvpn/
touch /var/log/openvpn.log
touch /var/log/openvpn/openvpn.log

