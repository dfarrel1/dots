function stest {    
    eval "sbt \" testOnly $1 \" "
}

function get_test_name {    
    b=$(basename $1)
    echo "${b%.*}"
}

get_tests() {
  export choice_set=`find . -type f | grep ".*test/*.scala"`
  get_choice $1
  testname=$(get_test_name "$2$choice_set$3")  
  [ "$choice_set" != "" ] && ( stest "*${testname}"  )
}
