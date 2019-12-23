HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
[[ ! -d ~/.vim ]] && ln -fs ${HERE}/../.vim/ ~/.vim
