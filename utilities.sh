#!/bin/ash

# Utilities
# Attention: Depends on config file

scriptpath="$( cd "$(dirname "$0")" ; pwd -P )"
source $scriptpath/arrays.sh

# Convert $1 (in bytes) to megabytes and return "$1(in MB) MB"
megabyte=$((10**6))
to_MB() {
    echo $(($1 / megabyte)) "MB"
}

# Return number of days in the month number $1
days_in_month () {
    days=0
    case "$1" in
    1 | 3 | 5 | 7 | 8 | 10 | 12)
        days=31
        ;;
    4 | 6 | 9 | 11)
        days=30
        ;;
    2)
        days=28
        ;;
    esac
    echo $days
}

# Return max of $1 and $2
get_max () {
    echo $(( $1 > $2 ? $1 : $2 ))
}

# Return max of $1 and $2
get_min () {
    echo $(( $1 < $2 ? $1 : $2 ))
}

# Remove any leading zeros of number $1
no_leading_zeros () {
    number=$(echo $1 | sed 's/^0*//')
    if [ -z "$number" ]; then
        # Just zeros result in an empty string
        echo 0
    else
        echo $number
    fi
}

# Get used data of pattern $1
get_used_data () {
    local pattern="\"$1\""
    local used=$(print_quotas | grep "quotaUsed\[ $pattern \]\[ $pattern \]" | cut -d ' ' -f 8)
    # Remove trailing comma
    local used=${used%?}
    if [ ! "$used" ]; then
        # "No quotaUsed found. Return 0"
	echo 0
    fi
    echo $used
}

# Return limit from firewall rules for quota id $1
get_limit () {
    local quota_id=$1
    local limit=$(uci get firewall.$quota_id.combined_limit)
    if [ ! $limit ]; then
	echo 0
    fi
    echo $limit
}

# Write arrays
#   used_data
#   current_limit
#   free_data
get_free_data() {
    for i in `seq $nusers`;do
        iprange=$(array_read "iprange" $i)
        quota_id=$(uci show firewall | grep id | grep $iprange | cut -d '.' -f 2)
        used_data=$(get_used_data $iprange)
        current_limit=$(get_limit $quota_id)
        free_data=$((current_limit - used_data))
        username=$(array_read "user" $i)
        array_write "used_data" $i $used_data
        array_write "current_limit" $i $current_limit
        array_write "free_data" $i $free_data
    done
}

# Print statistic table. Example output:
#        Name       Used      Limit       Free
#===============================================
#1    User1     12911 MB   13523 MB     611 MB
#2    User2      8872 MB    9484 MB     611 MB
#3    User3     17461 MB   18073 MB     611 MB
#4    User4      3649 MB    4261 MB     611 MB
print_statistic_table() {
    divider===============================
    divider=$divider$divider
    header="\n%2s %10s %10s %10s %10s\n"
    format="%2s %10s %10s %10s %10s %10s"
    width=47
    printf "$header" "#" "Name" "Used" "Limit" "Free"
    printf "%$width.${width}s\n" "$divider"
    for i in `seq $nusers`;do
        username=$(array_read "user" $i)
        used_data=$(array_read "used_data" $i)
        current_limit=$(array_read "current_limit" $i)
        free_data=$(array_read "free_data" $i)
        printf "$format" $i $username "$(to_MB $used_data)" "$(to_MB $current_limit)" "$(to_MB $free_data)"
        echo
    done
    echo
}

# Update the combined limits in the firewall rules
# by taking into account the new free_data:
#   new_limit = used_data + free_data
# The new firewall setting is then applied.
save_free_data() {
    for i in `seq $nusers`;do
        iprange=$(array_read "iprange" $i)
        quota_id=$(uci show firewall | grep id | grep $iprange | cut -d '.' -f 2)
        used_data=$(get_used_data $iprange)
        free_data=$(array_read "free_data" $i)
        next_limit=$((used_data + free_data))
        uci set firewall.$quota_id.combined_limit="$next_limit"
    done
    uci commit

    # Apply new quotas settings
    backup_quotas
    . /usr/lib/gargoyle_firewall_util/gargoyle_firewall_util.sh
    ifup_firewall
}

# Some dirty hacked way to extract the used data
get_telekom_usage() {
    telekom_usage=$(wget --user-agent="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:32.0) Gecko/20100101 Firefox/32.0" -c http://pass.telekom.de/ -T 2 -q -O - | grep -o ".\{0,10\}GB" | cut -d ">" -f 2)
    echo $telekom_usage
}
