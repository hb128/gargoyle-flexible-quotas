#!/bin/ash

scriptpath="$( cd "$(dirname "$0")" ; pwd -P )"
# Include config and utilties
. $scriptpath/config.sh
. $scriptpath/utilities.sh

echo "== Print free bandwidths. =="

get_free_data
print_statistic_table

exit
