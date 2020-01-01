export AWS_PROFILE=DataTeamRole

# add application password to keychain, okta-user
# add application password to keychain, okta
# bc keyring + gimme-aws-creds is buggy
okta_user=`security find-generic-password -a ${USER} -s okta-user -w`
alias sts='OKTA_PASSWORD="`security find-generic-password -a ${okta_user} -s okta -w`"  gimme-aws-creds'

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

# quick nav to work dirs
work() {
    # use local to avoid cmd shadowing    
    local stay="$(pwd)"
    local cdp="${GOPATH}/src/bitbucket.org/latchMaster/cdp/"
    local dots="${GOPATH}/src/github.com/dfarrel1/dots/"
    local airflow="${GOPATH}/src/github.com/Latch/cdp-airflow-dags/" 
    local docker="${GOPATH}/src/github.com/Latch/docker-images/"
    local ARR=('stay' 'cdp' 'dots' 'airflow' 'docker')
    [[ $# -eq 0 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice
    [[ $# -eq 1 ]] && choice_set=$1    
    IFS=@
    case "@${ARR[*]}@" in
        (*"@$choice_set@"*)
            eval "cd \$$choice_set";;
        (*)
            echo "${choice_set} is not a valid choice."
            IFS='|'; echo "[${ARR[*]}]";;
    esac 
    unset IFS   
}
