| Name | Type | Description |
|------|------|-------------|
| `1p` | alias | Start 1Password CLI session |
| `pb` | function | Copy the last shell command to clipboard (pasteboard) — `pb` |
| `get_list_of_tagged_secrets` | function | List 1Password items by tag name — `get_list_of_tagged_secrets <tag>` |
| `filter_array` | function | Filter a bash array by substring match (requires bash >= 4) — `filter_array <array-var-name> <filter-string>` |
| `choose_aws_secret` | function | Interactive picker for AWS secrets from 1Password — `choose_aws_secret [filter-string]` |
| `get_aws_acct_info` | function | Fetch AWS account info from a 1Password secret — `get_aws_acct_info` |
| `awskeys` | function | Export AWS access keys from 1Password to environment — `awskeys` |
| `mfa` | function | Get TOTP MFA code from 1Password and copy to clipboard — `mfa [secret-name]` |
| `newawslogin` | function | Create a new AWS login item template in 1Password — `newawslogin` |
| `newawsprofile` | function | Create a new aws-vault profile from a 1Password secret — `newawsprofile` |
| `awsloginbash` | function | (Deprecated) AWS console login via aws-vault with MFA + browser choice — `awsloginbash [filter-string]` |
