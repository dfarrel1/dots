#!/bin/bash
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

### Need to get config file (assuming it's in Downloads dir here)
conf_file=$(cd ~; pwd)/Downloads/client.ovpn

# need to add okta creds to keyychain
# security add-generic-password -a ${USER} -s okta-user -w <okta-user>
# security add-generic-password -a ${USER} -s okta -w <okta-password>

[[ ! $(grep "openvpn.log" ${conf_file}) ]] \
&& echo "log /var/log/openvpn.log" >> ${conf_file}

auth_file="/usr/local/etc/openvpn/vpnclient.auth"
auth_user_pass_file="/usr/local/etc/openvpn/custom/auth_user_pass.txt"
[[ ! -d /usr/local/etc/openvpn/custom/ ]] && mkdir -p /usr/local/etc/openvpn/custom/
touch ${auth_user_pass_file}


[[ ! $(grep "askpass" ${conf_file}) ]] \
&& echo "auth-user-pass ${auth_user_pass_file}" >> ${conf_file}


okta_user=`security find-generic-password -a ${USER} -s okta-user -w`
echo `security find-generic-password -a ${okta_user} -s okta -w` > ${auth_file} \
&& chmod 600 ${auth_file}

echo ${okta_user} > ${auth_user_pass_file} \
&& echo `security find-generic-password -a ${okta_user} -s okta -w` >> ${auth_user_pass_file} \
&& chmod 600 ${auth_user_pass_file}

[[ -f ${conf_file} ]] &&  cp ${conf_file} /usr/local/etc/openvpn/client.ovpn

sudo cp ${HERE}/openvpn.conf /etc/newsyslog.d/
sudo cp ${HERE}/openvpn.latch.client.plist /Library/LaunchDaemons/

[[ ! -d /var/log/openvpn/ ]] && mkdir /var/log/openvpn/
sudo touch /var/log/openvpn.log
sudo touch /var/log/openvpn/openvpn.log

