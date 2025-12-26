# managing aws user access with mfa

## direnv

[dots](https://github.com/dfarrel1/dots) does configure `aws-vault` globally
now, but to locally configure `aws-vault` per repo you can apply the following
steps with `direnv`.

configure `aws-vault` with `direnv`

`.envrc`:

```bash
export AWS_VAULT_KEYCHAIN_NAME=login
# Make Chamber read ~/.aws/config
export AWS_SDK_LOAD_CONFIG=1
# Make Chamber use the default AWS KMS key
export CHAMBER_KMS_KEY_ALIAS='alias/aws/ssm'
# Make Chamber use path based keys ('/' instead of '.')
export CHAMBER_USE_PATHS=1
```

then `direnv allow`

## aws-vault

### gotcha

https://github.com/99designs/aws-vault/issues/564

GetFederationToken api call which is used for profiles without role_arn does not
support MFA

(must specify a role_arn)

### create config

add a ~/.aws/config file

```text
[profile <default-profile>]
region=<region>
output=json
mfa_serial=arn:aws-us-gov:iam::<account>:mfa/<user>

[profile <role-based-profile>]
region=<region>
output=json
role_arn = arn:aws-us-gov:iam::<account>:role/<role>
mfa_serial=arn:aws-us-gov:iam::<account>:mfa/<user>

[profile admin]
region=<region>
output=json
role_arn=arn:aws-us-gov:iam::<account>:role/admin
mfa_serial=arn:aws-us-gov:iam::<account>:mfa/<firstname.lastname>
```

### setup aws mfa

[aws-docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html)

### create aws access key

[aws-docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey)

### setup aws-vault

first `aws-vault list` should list the roles you've provided in the config file.

then `aws-vault add <profile>` should allow you to add a profile, prompting you
to include your ACCESS KEY and SECRET.

### using aws-vault

```
# Execute a command using temporary credentials
aws-vault exec home -- aws s3 ls

# Open browser and log in to AWS console
aws-vault login work
````

### using `dots` aliases


https://github.com/dfarrel1/dots/profile/mac.sh
