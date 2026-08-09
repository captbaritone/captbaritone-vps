#!/bin/bash

source "$(dirname "$0")/tier.sh"

today=$(date +"%Y-%m-%d")
tier=$(tier_for_today)
backupdir=~/captbaritone-vps/backup/jordaneldredge-$today
mkdir $backupdir
sqlbackupfile=$backupdir/jordaneldredge.sqlite3.gz

sqlite3 ~/projects/jordaneldredge.com/content.db ".backup '$backupdir/jordaneldredge.sqlite3'"
gzip -c $backupdir/jordaneldredge.sqlite3 > $sqlbackupfile
rm $backupdir/jordaneldredge.sqlite3

/usr/local/bin/aws s3 --profile=backup-agent mv $sqlbackupfile s3://jordaneldredge-backup-bucket/jordaneldredge.com/$tier/db_backup_archive_$today.sqlite3.gz
rm -r $backupdir
