#!/bin/bash

printf "%-10s %-5s %-5s %-10s %s\n" "PID" "TTY" "STAT" "TIME" "COMMAND"

for pid in /proc/[0-9]*/; do
    # Get the process ID from the directory name
    pid="${pid%/}"
    pid="${pid##*/}"

    # Read the TTY from the process's stat file
    tty=$(awk '{print $7}' /proc/$pid/stat)
    case $tty in
      "0")
        tty="0"
      ;;
      "1025")
        tty="tty1"
      ;;
      "34816")
        tty="pts/0"
      ;;
      "34817")
        tty="pts/1"
      ;;
    esac
    
    # Read the process's status from the status file
    status=$(awk '/State/ {print $2}' /proc/$pid/status)
    nice=$(awk '{print $19}' /proc/$pid/stat)
    # priority
    case $nice in
      "-20")
        status="${status}<"
      ;;
      "19")
        status="${status}N"
      ;;            
    esac
    # session leader
    nssid=$(awk '/NSsid/ {print $2}' /proc/$pid/status)   
    if [ "$nssid" = "$pid" ]; then
      status="${status}s"
    fi
    # multithread
    mt=$(find /proc/$pid/task -mindepth 1 -maxdepth 1 -type d | wc -l)
    if [ "$mt" != 1 ]; then
      status="${status}l"
    fi
    # foreground process group
    fg=$(awk '{print $8}' /proc/$pid/stat)
    if [ "$fg" = "$pid" ]; then
      status="${status}+"
    fi
    
    # Read the process's command line from the cmdline file
    read -r cmd < /proc/$pid/cmdline
    if [ "$cmd" = "" ]; then
      cmd="[$(awk '/Name/ {print $2}' /proc/$pid/status)]"
    else
      cmd=$(tr '\0' ' ' < /proc/$pid/cmdline)   # replace 0 to ' '
      cmd=$(echo "$cmd" | xargs)                # remove trailing whitespaces
    fi

    # Read the process's total CPU time from the stat file
    utime=$(awk '{print $14}' /proc/$pid/stat)  # process has been runnung in user mode
    stime=$(awk '{print $15}' /proc/$pid/stat)  # process has been running in kernel mode
    tics=$(getconf CLK_TCK)
    total_time=$((utime + stime))
    total_time=$((total_time / $tics))

    # Print the process information in the same format as ps ax
    printf "%-10s %-5s %-5s %02d:%02d:%02d %s\n" "$pid" "$tty" "$status" "$(($total_time / 3600))" "$((($total_time % 3600) / 60))" "$(($total_time % 60))" "$cmd"

done | sort -n -k1

