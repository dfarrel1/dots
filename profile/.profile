[[ "$0" =~ "dotfiles/profile" ]] && PROFILE_DIR=$(dirname $0) || PROFILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

GOPATH=~

sources=( core navigation git-completion docker python java latch scala mac git )
for i in "${sources[@]}"
do
    source "$PROFILE_DIR/$i.sh" > /dev/null
done