#!/bin/ash

# Include config and utilties
scriptpath="$( cd "$(dirname "$0")" ; pwd -P )"
source $scriptpath/config.sh
source $scriptpath/utilities.sh

echo "== Set free datas manual. =="

get_free_data
print_statistic_table

echo "Select entries to change (comma seperated)"
read entries

echo
for i in $(echo $entries | sed "s/,/ /g");do
    free_data=$(array_read "free_data" $i)
    free_data_MB=$(($free_data / $megabyte))
    echo "$i) Free data in MB: $free_data_MB"
    echo "New free data in MB:"
    read free_data_MB
    free_data=$(($free_data_MB * $megabyte))
    array_write "free_data" $i $free_data
done

save_free_data
echo "New statistics:"
print_statistic_table

exit
