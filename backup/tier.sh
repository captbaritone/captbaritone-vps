# Shared helper: pick today's retention tier.
# Sourced by the daily backup scripts to decide which S3 subprefix
# (daily/weekly/monthly/yearly) a given day's backup should land in.
# Lifecycle rules on the bucket then expire each tier at the right age.
#
# Rule: highest-retention tier a date qualifies for wins.
#   Jan 1                       -> yearly
#   1st of any other month      -> monthly
#   Monday (any other day-1)    -> weekly
#   otherwise                   -> daily

tier_for_today() {
    local dow dom doy
    dow=$(date +"%u")   # 1-7, Monday=1
    dom=$(date +"%d")   # 01-31
    doy=$(date +"%j")   # 001-366

    if [ "$doy" = "001" ]; then
        echo "yearly"
    elif [ "$dom" = "01" ]; then
        echo "monthly"
    elif [ "$dow" = "1" ]; then
        echo "weekly"
    else
        echo "daily"
    fi
}
