# BackuPI
backpi is a backup script for raspberry pi devices.

## crontab settings
```
0 1 * * * /opt/backup.sh --proto=smb --host=192.168.1.1 --dir=backup --user=myuser --pass=mypass --title=server
0 2 * * * /opt/backup.sh --proto=ssh --host=192.168.1.2 --dir=/home/filio/Documents --user=myuser --title=desktop
```
