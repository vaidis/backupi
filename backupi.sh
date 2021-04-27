#!/bin/bash
#
# Usage: backup.sh --proto=[smb|ssh] --host=[address] --dir=[source dir] --user=[username] --pass=[password]"
# 
# Example: backup.sh --proto=smb --host=192.168.1.2 --dir=Documents --user=admin --pass=1234"
# Example: backup.sh --proto=ssh --host=192.168.1.2 --dir=/home/ste/Documents --user=admin"
#
# Simple backup script used with cron to sync a remote folder with a usb stick using smb or ssh
#

function log() {
    echo -e "`date +'%d/%m/%Y %H:%M:%S'` | $1"
    echo -e "`date +'%d/%m/%Y %H:%M:%S'` | $1" >> $LOGFILE
}

function usage() {
    echo $1
    echo
    echo -e "backup.sh --proto=[smb|ssh] --host=[address] --dir=[source dir] --user=[username] --pass=[password]"
    echo
    echo -e "backup.sh --proto=smb --host=192.168.1.220 --dir=backup --user=filio --pass=1234 --delete=yes"
    echo -e "backup.sh --proto=ssh --host=192.168.1.2 --dir=/home/ste/Documents --user=admin"
    echo
    exit
}

function mount_smb() { 
    if mount -t cifs //$HOST/$DIR /mnt/$SRC -o username=$USER,password=$PASS; then
        log "[ OK ] mount //$HOST/$DIR to /mnt/$SRC"
        return 0
    else
        log "[FAIL] mount //$HOST/$DIR to /mnt/$SRC"
        return 1
    fi
}

function mount_ssh() {
    if ssh -q  -o BatchMode=yes -o ConnectTimeout=10 $USER@$HOST exit; then
        if ssh $USER@$HOST ls $DIR 2> /dev/null; then
            if sshfs -o ro $USER@$HOST:$DIR /mnt/$SRC; then
                return 0
            else
                log "[FAIL] mount $USER@$HOST:$DIR to /mnt/$SRC"
                return 1
            fi
        else
            log "[FAIL] remote dir $DIR not found"
            return 1
        fi
    else
        log "[FAIL] ssh $USER@$HOST"
        return 1
    fi
}

function mount_usb() {
    if ! grep -qs '/mnt/usb ' /proc/mounts; then
        for devfile in `ls -1 /dev/sd[a-z]`; do
            log "[ OK ] found usb disk $devfile"
            if mount ${devfile}1 /mnt/usb; then
                [ -d /mnt/usb/backup ] || mkdir /mnt/usb/backup
                log "[ OK ] mount ${devfile}1 to /mnt/usb"
                return 0
            else
                log "[FAIL] mount ${devfile}1 to /mnt/usb"
                return 1
            fi
        done
    else
       log "[FAIL] /mnt/usb already mounted"
       return 1
    fi
}

function copy_files() {
    if [ -d "/mnt/$SRC" ]; then
        log "[ OK ] found dir /mnt/$SRC"
        cd /mnt/$SRC
        log "------- BACKUP STARTED --------"
        ls -l /mnt/usb/backup
        if [ "$DELETE" == "yes" ]; then
            rsync -av --stats \
                      --temp-dir=/tmp \
                      --human-readable \
                      --no-owner \
                      --no-group \
                      --exclude '.*' \
                      --delete \
                      ./ /mnt/usb/backup | tee $LOGFILE
        else
            #rsync -av -e "ssh -c arcfour" \
            rsync -av --stats \
                      --temp-dir=/tmp \
                      --human-readable \
                      --no-owner \
                      --no-group \
                      ./ /mnt/usb/backup | tee $LOGFILE
        fi

        echo >> $LOGFILE
        log "------- BACKUP ENDED ----------"
        cd /root
        return 0
    else
        log "[FAIL] found dir /mnt/$SRC"
        cd /root
        return 1
    fi
}

function umount_usb() {
    cd /root

    USBTOTAL=$(df -h | grep sda1 | awk '{print $2}')
    USBUSAGE=$(df -h | grep sda1 | awk '{print $5}')
    USBUSED=$(df -h | grep sda1 | awk '{print $3}')
    USBFREE=$(df -h | grep sda1 | awk '{print $4}')

    log " USB : ${USBUSAGE} from ${USBTOTAL}"
    log " USB : used: ${USBUSED}  / free: ${USBFREE}"

    cp $LOGFILE /mnt/usb/

    umount /dev/sd[a-z]1 -l &> /dev/null
    umount /mnt/usb      -l &> /dev/null

    if fusermount -u /mnt/$SRC ; then
        log "[ OK ] umount remote dir"
        countfiles=$(find /mnt/$SRC -type f | wc -l)
        if [ $countfiles -eq 0 ]  ; then
            rm -rf /mnt/$SRC
            log "[ OK ] deleting temporary dir"
        else
            log "[FAIL] deleting temporary dir"
        fi
    else
        log "[FAIL] umount remote dir"
    fi
}

function send_mail() {

    cat $LOGFILE | s-nail -v \
        -r "$mail_from" \
        -s "Backup Report" \
        -S mta=smtps://$mail_server_host:$mail_server_port \
        -S smtp-use-starttls \
        -S smtp-auth=login \
        -S smtp-auth-user="$mail_auth_user" \
        -S smtp-auth-password="$mail_auth_pass" \
        -S ssl-verify=ignore \
        "$mail_to"
     
    # swaks stop working with the 
    # new siteground shared accounts settings
    #
    #    swaks --body $LOGFILE \
    #    --from "$mail_from" \
    #    --to "$mail_to" \
    #    --header "$mail_header" \
    #    --server "$mail_server_host:$mail_server_port" \
    #    --auth LOGIN \
    #    --auth-user "$mail_auth_user" \
    #    --auth-password "$mail_auth_pass" \
    #    -tls

}

function mount_remote() {
    if ping -q -c1 -W2 $HOST &> /dev/null; then
        log "[ OK ] ping $HOST"
        case $PROTO in
            smb ) 
                if mount_smb; then
                    return 0
                else
                    return 1
                fi 
                ;;
            ssh ) 
                if mount_ssh; then
                    return 0
                else
                    return 1
                fi 
                ;;
              * ) 
                usage ;;
        esac
    else
        log "[FAIL] ping $HOST"
        return 1
    fi
}


commands=(rsync sshfs swaks)
for command in "${commands[@]}"
do
    if ! command -v ${command} > /dev/null; then
        echo -e "Command \e[96m$command\e[39m not found"

        exit
    fi
done

SRC=$$
mkdir /mnt/$SRC

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        --help)
            usage
            exit 1
            ;;
        --mount)
            usb_mount
            exit 0
            ;;
        --umount)
            usb_umount
            exit 0
            ;;
        --title)
            TITLE=$VALUE
            ;;
        --proto)
            PROTO=$VALUE
            ;;
        --host)
            HOST=$VALUE
            ;;
        --dir)
            DIR=$VALUE
            ;;
        --user)
            USER=$VALUE
            ;;
        --pass)
            PASS=$VALUE
            ;;
        --delete)
            DELETE=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

[ -z "$TITLE" ] && echo -e "missing \e[91m--title\e[39m option" && exit
[ -z "$PROTO" ] && echo -e "missing \e[91m--proto\e[39m option" && exit
[ -z "$HOST" ] && echo -e "missing \e[91m--host\e[39m option" && exit
[ -z "$DIR" ] && echo -e "missing \e[91m--dir\e[39m option" && exit
[ -z "$USER" ] && echo -e "missing \e[91m--user\e[39m option" && exit
if [ "$PROTO" = "smb" ];  then 
    [ -z "$PASS" ] && echo -e "missing \e[91m--pass\e[39m option" && exit
fi

LOG="/root/backup"
LOGFILE="${LOG}_${TITLE}.log"
mail_from="backup@mycompany.org"
mail_to="admin@gmail.com"
mail_header="Subject: Backup Report"
mail_auth_user="backup@mycompany.org"
mail_auth_pass="abc123"
mail_server_host="xyz123.siteground.eu"
mail_server_port="465"

echo > $LOGFILE
if mount_remote; then
    if mount_usb; then
        if copy_files; then
            log "[ OK ] backup finished"
        else
            log "[FAIL] backup finished"
        fi
    fi
fi

umount_usb
send_mail
 
