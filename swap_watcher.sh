#!/bin/bash
# Execute this in another shell and monitor for any change

while true; do 
    grep VmSwap "/proc/$(pgrep sorter)/status"
    sleep 10;
done
