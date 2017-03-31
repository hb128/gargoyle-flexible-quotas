## General

# Constants
megabyte=$((10**6))
gigabyte=$((10**9))
# Set this factor for overbooking and/or to account
# for some inaccuracy in data metering
quota_factor="107/100"
# Quota distributed to each user on the 1. day
start_quota=$((500*megabyte))
# Cap for free amount of data each user can save. Everything above will
# distributed evenly among all users.
maximal_savings=$((1300*megabyte))
# Days before end of month the cap for free amount of data is reduced.
# This helps to give all users (and especially power users) the possibility to
# use all data provided by the tarif
start_maximum_lowering=8
# Lower maximal saving linearly to
lowest_maximum=$((200*megabyte))
# Stop distribution of free data.
stop_distribution_days_before=1

## Users

nusers=4
user2="Alice"; iprange2="192.168.1.50-192.168.1.59"; monthly_quota2=$((20*gigabye))
user1="Bob"; iprange1="192.168.1.60-192.168.1.69"; monthly_quota1=$((10*gigabye))

## Mail settings

mailsmtp="imap.example.de"
mailuser="gargoyle@example.com"
mailpassword="passphrase"
mailsender="gargoyle@example.com"
recipientshourly="your@mail.com"
logfilehourly="/root/flexible-quotas-hourly.log"
