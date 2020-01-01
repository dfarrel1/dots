export AWS_PROFILE=DataTeamRole

alias sts='gimme-aws-creds'

# for use with `sbt stage`
alias cdp='./target/universal/stage/bin/cdp-data-transformer'
alias cdp-prod='export JAVA_OPTS="-Xmx4g -Denv=prod" && cdp'

# OpenVPN
export PATH=/usr/local/opt/openvpn/sbin:$PATH
######## SETUP ######
# [cli openvpn is super slow (?)]
# download connection profile from server: https://vpn.latch.com/?src=connect 
#
# security add-generic-password -a ${USER} -s openvpn-user -w <vpn-user>
# security add-generic-password -a ${USER} -s openvpn -w <vpn-password>
#
# visudo #(not working)
# <user>             ALL = (ALL) NOPASSWD: /bin/bash vpn
# <user>             ALL = (ALL) NOPASSWD: /bin/bash killvpn

alias fresh_vpn="sudo ${HERE}/../xtra/vpn/refresh-vpn.sh"

# from terminal
vpn () {
    tmpfile=$(mktemp /tmp/openvpn-creds.XXXXXX)
    echo `security find-generic-password -a ${USER} -s openvpn-user -w` >&${tmpfile}
    echo `security find-generic-password -a ${USER} -s openvpn -w` >>${tmpfile}
    sudo openvpn --config /usr/local/etc/openvpn/client.ovpn --auth-user-pass $tmpfile --daemon
    rm "$tmpfile"
}

alias gvpn='ps aux | grep -i "openvpn --config"'
alias killvpn="ps aux | grep -i 'openvpn --config' | awk {'print \$2'} | xargs sudo kill -9"    

# with launchctl
alias vpnlog='sudo tail -f  /var/log/openvpn.log'
alias loadvpn='sudo launchctl load -w /Library/LaunchDaemons/openvpn.latch.client.plist'
alias unloadvpn='sudo launchctl unload -w /Library/LaunchDaemons/openvpn.latch.client.plist'
alias startvpn='sudo launchctl start openvpn.latch.client'
alias stopvpn='sudo launchctl stop openvpn.latch.client'
alias listvpn='sudo launchctl list | grep vpn'


