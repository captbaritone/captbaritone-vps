#!/bin/bash

today=$(date +"%Y-%m-%d")
backupdir=~/captbaritone-vps/backup/jordaneldredge-$today
mkdir $backupdir
sqlbackupfile=$backupdir/jordaneldredge.sqlite3.gz

sqlite3 ~/projects/jordaneldredge.com/content.db ".backup '$backupdir/jordaneldredge.sqlite3'"
gzip -c $backupdir/jordaneldredge.sqlite3 > $sqlbackupfile
rm $backupdir/jordaneldredge.sqlite3

/usr/local/bin/aws s3 --profile=backup-agent mv $sqlbackupfile s3://jordaneldredge-backup-bucket/jordaneldredge.com/db_backup_archive_$today.sqlite3.gz
rm -r $backupdir
