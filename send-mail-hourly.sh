#!/bin/ash

scriptpath="$( cd "$(dirname "$0")" ; pwd -P )"

#!/bin/sh
if [ "$#" -ne 1 ] || ! [ -f "$1" ]; then
  echo "Usage: $0 logfile" >&2
  exit 1
fi
logfile=$1

# Load config
source $scriptpath/config.sh

mailsend -f $mailsender -t $recipientshourly -smtp $mailsmtp -startssl -user $mailuser -auth -pass $mailpassword -port 587 -sub "Gargoyle Hourly $(date)" -mime-type "text/plain" -msg-body $logfile
