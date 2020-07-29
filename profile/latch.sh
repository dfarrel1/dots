# A few convenience functions to make 
# life easier as a developer at Latch

export AWS_PROFILE=DataTeamRole

# add application passwords to keychain, 'okta-user' and 'okta'
# security add-generic-password -a ${USER} -s okta-user -w <okta-user>
# security add-generic-password -a <okta-user> -s okta -w <okta-pass>

# keyring + gimme-aws-creds is buggy
okta_user=`security find-generic-password -a ${USER} -s okta-user -w`
alias sts='OKTA_PASSWORD="`security find-generic-password -a ${okta_user} -s okta -w`"  gimme-aws-creds'

# for use with `sbt stage`
alias cdp='./target/universal/stage/bin/cdp-data-transformer'
alias cdp-prod='export JAVA_OPTS="-Xmx4g -Denv=prod" && cdp'

# OpenVPN
export PATH=/usr/local/opt/openvpn/sbin:$PATH
######## SETUP ######
# # 1. download connection profile from server: https://vpn.latch.com/?src=connect 
#
# # 2. make sure 'okta-user' and 'okta' are set in os-x-keychain
#
# # 3. sudoers
# visudo
# <user>             ALL = (ALL) NOPASSWD: /bin/bash openvpn
#
# # note: make sure you don't shadow user with admin group rule 
# # bc that will nullify these additions to the sudoers file

alias fresh_vpn="${HERE}/../xtra/vpn/refresh-vpn.sh"

# from terminal
vpn () {
    local okta_user=`security find-generic-password -a ${USER} -s okta-user -w`
    local okta_pass=`security find-generic-password -a ${okta_user} -s okta -w`
    tmpfile=$(mktemp /tmp/openvpn-creds.XXXXXX)
    echo ${okta_user} >&${tmpfile}
    echo ${okta_pass} >>${tmpfile}
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


# # quick nav to commonly used dirs
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
quickdirs() {
    # get directory categories (files under quickdirs dir)
    if [ "$#" -lt 1 ]; then
        dir_cats_arr=( $(ls ${HERE}/quickdirs/) )
        [[ $# -eq 0 ]] && choice_set=`printf '%s\n' "${dir_cats_arr[@]}"` && get_choice
        IFS=@
        case "@${dir_cats_arr[*]}@" in
            (*"@$choice_set@"*)                
                eval "dir_cat=$choice_set";;                
            (*)
                echo "${choice_set} is not a valid dir category choice."
                IFS='|'; echo "[${dir_cats_arr[*]}]";;
        esac
        unset IFS
    else
        dir_cat=$1
    fi
    
    # get destination directory (line in file)
    local stay="$(pwd)"    
    local ARR=("stay")        
    while IFS='=' read -r col1 col2
    do 
        eval "local ${col1}=${col2}"
        ARR+=("$col1")
    done <"${HERE}/quickdirs/${dir_cat}"

    [[ $# -lt 2 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice
    [[ $# -eq 2 ]] && choice_set=$2    
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

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
