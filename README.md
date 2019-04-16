# BackuPI
backpi is a simple backup script used with cron to sync remote folders with a usb stick using smb or ssh

## crontab settings
```
0 1 * * * /opt/backupi.sh --proto=smb --host=10.0.0.1 --dir=Documents --user=myuser --pass=mypass --title=server
0 2 * * * /opt/backupi.sh --proto=ssh --host=10.0.0.2 --dir=/home/myuser/Documents --user=myuser --title=desktop
```
