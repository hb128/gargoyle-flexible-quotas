#!/bin/ash

# Helper function to write array like elements like range2
# Example to set myarray[0] = 42:
# array_write "myarray" 0 42
array_write() {
    local __array=$1
    local index=$2
    local value=$3
    eval "$__array"$index=$value
}

# Helper function to access array like elements like range2
# Example to set x = myarray[0]
# x=$(array_read "myarray" 0)
array_read() {
    local __array=$1
    local index=$2
    eval echo \$"$__array"$index
}
