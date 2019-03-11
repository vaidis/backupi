# BackuPI
backpi is a backup script for raspberry pi devices.

## crontab settings
````
0 1 * * 1,2,3,4,5 /bin/bash /root/backup.sh --proto=smb --host=192.168.1.101 --dir=backup --user=myuser --pass=mypass --title=server
0 2 * * 1,2,3,4,5 /bin/bash /root/backup.sh --proto=ssh --host=192.168.1.2 --dir=/home/filio/Documents/myuser --user=myuser --title=desktop
```
