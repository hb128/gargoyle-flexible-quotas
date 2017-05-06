#!/bin/ash

# Include config and utilties
scriptpath="$( cd "$(dirname "$0")" ; pwd -P )"
source $scriptpath/config.sh
source $scriptpath/utilities.sh

echo "== Update quotas. =="
current_month=$(no_leading_zeros $(date +%m))
days_this_month=$(days_in_month $current_month)
current_day=$(no_leading_zeros $(date +%d))
current_hour=$(no_leading_zeros $(date +%H))
left_days=$((days_this_month - current_day - stop_distribution_days_before))
left_hours=$((left_days * 24 + (24 - current_hour)))
echo "This is day $current_day/$days_this_month. $(get_max $left_days 0) days or $(get_max $left_hours 0) hours are left to distribute left quota."

if [ "$left_days" -le "$start_maximum_lowering" ] && [ "$left_days" -ge 0 ]; then
    # Lower maximal savings the last $lower_maximum_before_month_end days
    maximal_savings=$(($lowest_maximum + ($maximal_savings - $lowest_maximum) * $left_days / $start_maximum_lowering))
    echo "Lower maximal savings to:" $(to_MB $maximal_savings)
elif [ "$left_days" -lt 0 ]; then
    # Set maximal saving to minimum when distribution phase stops
    maximal_savings=$lowest_maximum
    echo "Set maximal savings to minimum:" $(to_MB $maximal_savings)
fi

get_free_data
echo "Current statistics:"
print_statistic_table

if [ "$current_day" -eq 1 ] && [ "$current_hour" -eq 0 ]; then
    # Reset free  to $start_quota at the 1. of the month at 00:01
    # The free data represents (modulo the usage from 00:00 to 00:01) the quota
    # because the used data has been reseted on minute before by the gargoyle firmware.
    echo "New month begins. Reset free data to start quota of" $(to_MB $start_quota)
    for i in `seq $nusers`;do
        array_write "free_data" $i $start_quota
    done
fi

# Sum total left quota, (distributed) quota and used data.
total_left_quota=0
total_quota=0
total_used_data=0
for i in `seq $nusers`;do
    array_write "free_data_before" $i $(array_read "free_data" $i)
    used_data=$(array_read "used_data" $i)
    current_limit=$(array_read "current_limit" $i)
    monthly_quota=$(array_read "monthly_quota" $i)
    monthly_quota=$((monthly_quota * quota_factor))
    left_quota=$((monthly_quota - current_limit))

    total_left_quota=$((total_left_quota + left_quota))
    total_quota=$((total_quota + monthly_quota))
    total_used_data=$((total_used_data + used_data))
done

echo "Total left quota:" $(to_MB $total_left_quota) "/" $(to_MB total_quota)s
if [ "$total_left_quota" -lt 0 ]; then
    echo "A negative quota should not happen, set to default 1000 MB"
    total_left_quota=1000000000
fi

# Increment free data for all users if left hours is above 0
total_distributed_data=0
total_increment_data=0
if [ "$left_hours" -gt 0 ]; then
    for i in `seq $nusers`;do
        array_write "free_data_before" $i $(array_read "free_data" $i)
        current_limit=$(array_read "current_limit" $i)
        free_data=$(array_read "free_data" $i)
        monthly_quota=$(array_read "monthly_quota" $i)
        monthly_quota=$((monthly_quota * quota_factor))
        # Weight Total left quota with relative monthly quota
        increment_data=$(((total_left_quota * ((monthly_quota) / (total_quota / 1000)) / left_hours) / 1000))
        echo "$i) Add" $(to_MB $increment_data)
        free_data=$((free_data + increment_data))
        array_write "free_data" $i $free_data
        total_distributed_data=$((total_distributed_data + current_limit + increment_data))
        total_increment_data=$((total_increment_data + increment_data))
    done
else
    echo "No hours left. Do not distribute any new data."
fi

# Check if any free data is above maximal allowed savings.
data_to_share=0
n_users_not_too_much=0
for i in `seq $nusers`;do
    free_data=$(array_read "free_data" $i)
    if [ "$free_data" -gt "$maximal_savings" ]; then
        to_share=$((free_data - maximal_savings))
        echo "$i:" $(to_MB $free_data) "exceeds maximal savings. To Share:" $(to_MB $to_share)
        data_to_share=$((data_to_share + to_share))
        array_write "user_with_too_much_savings" $i 1
        free_data=$maximal_savings
    else
        array_write "user_with_too_much_savings" $i 0
        n_users_not_too_much=$((n_users_not_too_much + 1))
    fi
    array_write "free_data" $i $free_data
done

# Distribute excess data evenly to not exceeding users.
further_data_to_share=0
if [ "$n_users_not_too_much" -gt 0 ] && [ "$data_to_share" -gt 0 ]; then
    echo "Redistribute data of" $(to_MB $data_to_share) "to $n_users_not_too_much users."
    for i in `seq $nusers`;do
        free_data=$(array_read "free_data" $i)
        if [ $(array_read "user_with_too_much_savings" $i) == 0 ]; then
            additional_data=$((data_to_share / n_users_not_too_much))
            echo "$i) Add" $(to_MB $additional_data)
            free_data=$((free_data + additional_data))
            if [ "$free_data" -gt "$maximal_savings" ]; then
                to_share=$((free_data - maximal_savings))
                echo "$i)" $(to_MB $free_data) "exceeds maximal savings. To Share in round 2:" $(to_MB $to_share)
                further_data_to_share=$((further_data_to_share + to_share))
                free_data=$maximal_savings
            fi
        fi
        array_write "free_data" $i $free_data
    done
else
    further_data_to_share=$data_to_share
fi

# Distribute still remaining data to all useres evenly.
if [ "$further_data_to_share" -gt 0 ]; then
    echo "Redistribute any still exceeding data of" $(to_MB $further_data_to_share) "to all users."
    for i in `seq $nusers`;do
        free_data=$(array_read "free_data" $i)
        additional_data=$((further_data_to_share / nusers))
        echo "$i) Add" $(to_MB $additional_data)
        free_data=$((free_data + further_data_to_share / nusers))
        array_write "free_data" $i $free_data
    done
fi

echo "Save free data."
save_free_data

echo "Free Bandwidth: before -> after"
increment_data_checksum=0
for i in `seq $nusers`;do
    before=$(array_read "free_data_before" $i)
    after=$(array_read "free_data" $i)
    increment_data_checksum=$((increment_data_checksum + after - before))
    echo "$i)" $(to_MB $before) "->" $(to_MB $after)
done
increment_diff=$((increment_data_checksum - total_increment_data))
if [ "$increment_diff" -lt 0 ]; then
    increment_diff=$((- increment_diff))
fi
maximal_margin=50
if [ "$increment_diff" -gt "$maximal_margin" ]; then
    echo "Added data checksum not OK!"
    echo "Checksum of " $increment_data_checksum "is not indended increment of" $total_increment_data
fi

echo "Total new added data:" $(to_MB $total_increment_data)
echo "Total distributed data:" $(to_MB $total_distributed_data)
echo "Total used data:" $(to_MB $total_used_data)
echo "Telekom used data:" $(get_telekom_usage)
echo "New statistics:"
print_statistic_table

exit 0
