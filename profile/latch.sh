export AWS_PROFILE=DataTeamRole

alias sts='gimme-aws-creds'

# for use with `sbt stage`
alias cdp='./target/universal/stage/bin/cdp-data-transformer'
alias cdp-prod='export JAVA_OPTS="-Xmx4g -Denv=prod" && cdp'