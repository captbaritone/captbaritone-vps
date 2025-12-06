#!/bin/bash

today=$(date +"%Y-%m-%d")
backupdir=~/captbaritone-vps/backup/capt-$today
mkdir $backupdir
sqlbackupfile=$backupdir/capt.sqlite3.gz

sqlite3 ~/projects/capt-rs/db.sqlite ".backup '$backupdir/capt.sqlite3'"
gzip -c $backupdir/capt.sqlite3 > $sqlbackupfile
rm $backupdir/capt.sqlite3

/usr/local/bin/aws s3 --profile=backup-agent mv $sqlbackupfile s3://jordaneldredge-backup-bucket/capt.dev/db_backup_archive_$today.sqlite3.gz
rm -r $backupdir
