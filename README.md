# BackuPI
backpi is a imple backup script used with cron to sync remote folders with a usb stick using smb or ssh

## crontab settings
```
0 1 * * * /opt/backupi.sh --proto=smb --host=192.168.1.1 --dir=backup --user=myuser --pass=mypass --title=server
0 2 * * * /opt/backupi.sh --proto=ssh --host=192.168.1.2 --dir=/home/filio/Documents --user=myuser --title=desktop
```
