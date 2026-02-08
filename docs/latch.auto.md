| Name | Type | Description |
|------|------|-------------|
| `sts` | alias | `'OKTA_PASSWORD="`security find-generic-password -a...` |
| `cdp` | alias | `'./target/universal/stage/bin/cdp-data-transformer...` |
| `cdp-prod` | alias | `'export JAVA_OPTS="-Xmx4g -Denv=prod" && cdp'` |
| `fresh_vpn` | alias | `"${HERE}/../xtra/vpn/refresh-vpn.sh"` |
| `gvpn` | alias | `'ps aux | grep -i "openvpn --config"'` |
| `killvpn` | alias | `"ps aux | grep -i 'openvpn --config' | awk {'print...` |
| `vpnlog` | alias | `'sudo tail -f  /var/log/openvpn.log'` |
| `loadvpn` | alias | `'sudo launchctl load -w /Library/LaunchDaemons/ope...` |
| `unloadvpn` | alias | `'sudo launchctl unload -w /Library/LaunchDaemons/o...` |
| `startvpn` | alias | `'sudo launchctl start openvpn.latch.client'` |
| `stopvpn` | alias | `'sudo launchctl stop openvpn.latch.client'` |
| `listvpn` | alias | `'sudo launchctl list | grep vpn'` |
| `vpn` | function | — |
| `quickdirs` | function | — |
