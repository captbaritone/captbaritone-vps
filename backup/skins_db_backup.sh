#!/bin/bash

source "$(dirname "$0")/tier.sh"

today=$(date +"%Y-%m-%d")
tier=$(tier_for_today)
backupdir=~/captbaritone-vps/backup/skins-$today
mkdir $backupdir
sqlbackupfile=$backupdir/winamp_skins.sqlite3.gz


# Use sqlite3 .backup for a safe backup in WAL mode
sqlite3 ~/projects/webamp/packages/skin-database/skins.sqlite3 ".backup '$backupdir/winamp_skins.sqlite3'"
gzip -c $backupdir/winamp_skins.sqlite3 > $sqlbackupfile
rm $backupdir/winamp_skins.sqlite3

/usr/local/bin/aws s3 --profile=backup-agent mv $sqlbackupfile s3://jordaneldredge-backup-bucket/skins_database/$tier/skins_db_backup_archive_$today.sqlite3.gz
rm -r $backupdir
