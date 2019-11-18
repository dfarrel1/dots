[[ "$0" =~ "dotfiles/profile" ]] && PROFILE_DIR=$(dirname $0) || PROFILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

GOPATH=~

sources=( core navigation git docker python java latch git-completion scala mac)
for i in "${sources[@]}"
do
    source "$PROFILE_DIR/$i.sh"
done
