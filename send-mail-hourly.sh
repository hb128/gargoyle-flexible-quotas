#!/bin/ash

scriptpath="$( cd "$(dirname "$0")" ; pwd -P )"

# Load config
source $scriptpath/config.cfg

mailsend -f $mailsender -t $recipientshourly -smtp $mailsmtp -startssl -user $mailuser -auth -pass $mailpassword -port 587 -sub "Gargoyle Hourly $(date)" -mime-type "text/plain" -msg-body $logfilehourly
