function stest {    
    eval "sbt \" testOnly $1 \" "
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
    ( stest "*${testname}"  )
  fi
}
