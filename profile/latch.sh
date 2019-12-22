export AWS_PROFILE=DataTeamRole

alias sts='gimme-aws-creds'

# for use with `sbt stage`
alias cdp='./target/universal/stage/bin/cdp-data-transformer'
alias cdp-prod='export JAVA_OPTS="-Xmx4g -Denv=prod" && cdp'

# OpenVPN
export PATH=/usr/local/opt/openvpn/sbin:$PATH
######## SETUP ######
# download connection profile from server: https://vpn.latch.com/?src=connect
# cp client.ovpn /usr/local/etc/openvpn/client.ovpn
#
# security add-generic-password -a ${USER} -s openvpn-user -w <user>
# security add-generic-password -a ${USER} -s openvpn -w <password>
#
# visudo
# vpn             ALL = (ALL) NOPASSWD: /bin/bash vpn
# vpn             ALL = (ALL) NOPASSWD: /bin/bash killvpn

vpn () {
    tmpfile=$(mktemp /tmp/openvpn-creds.XXXXXX)
    echo `security find-generic-password -a ${USER} -s openvpn-user -w` >&${tmpfile}
    echo `security find-generic-password -a ${USER} -s openvpn -w` >>${tmpfile}
    sudo openvpn --config /usr/local/etc/openvpn/client.ovpn --auth-user-pass $tmpfile --daemon
    rm "$tmpfile"
}

killvpn () {
    ps aux | grep -i "openvpn --config" | awk {'print $2'} | xargs sudo kill -9
}