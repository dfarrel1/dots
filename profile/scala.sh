function stest {    
    eval "sbt \" testOnly $1 \" "
}

function dc_stest {    
    eval "docker exec -it cdp-etl-container /bin/bash -c 'sbt \"testOnly *${1}\"'"
}

function get_test_name {    
    b=$(basename $1)
    echo "${b%.*}"
}

get_tests() {
  export choice_set=`find . -type f | grep ".*test/*.scala"`   
  if [ "$choice_set" != "" ]
  then 
    [ ! -z "$1" ] && export choice_set=`grep -l $1 $choice_set` #use input to filter
    [[ ! $choice_set == *$'\n'* ]] && echo -e "running test: $choice_set" #print if only one
    get_choice $1 && testname=$(get_test_name "$2$choice_set$3")  #chose if more than one
    ( dc_stest "*${testname}"  )
  fi
}


# grep and print a list of clickable files for hits
# requires gnu-sed (brew install gnu-sed)
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color
export ESC_PWD=$(echo "${PWD}" | sed 's/\//\\\//g')
function RM_COLOR { 
  gsed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" 
  }
function LINES2FILES { 
  cut -d " " -f1 | cut -d ':' -f 1 | sort -u 
  }
function FILE2LINK { 
  sed -e 's/^/idea:\/\/open\?file='"${ESC_PWD}\/"'/' 
  }
function RM_TRAILING_COLON { 
  sed 's/:*$//g' 
  }

clicks() {
  git grep -n --color=always $1 | \
  tee >( RM_COLOR | LINES2FILES | FILE2LINK |  RM_TRAILING_COLON | \
  xargs -I {} sh -c 'printf "'${CYAN}'{}'${NC}' \n"' ) 
}


help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
