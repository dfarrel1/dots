# Continuous Tether

Something to reduce the tediousness of maintaining a hotspot tether.

The creds are stored in an untracked env file. 

## Update crontab

1. Open Terminal.
2. Type `crontab -e` to open your cron table for editing.
3. Add the following line to your cron table.
```
* * * * * <your-script>
```