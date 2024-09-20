#!/bin/bash

# Checks, if root permissions
if [ $(id -u) -ne 0 ]
   then echo "Error: needing root permissions!" >&2
  exit 1
fi

# Shows help, if no PID is given
if [ -z "$1" ]
   then
       echo "Usage:"
       echo -e "\gdbcore_v2 <PID> <all>"
       echo
       echo "Example:"
       echo -e "\t./gdbcore_v2 1137 "
       exit 0
elif [ $1 == all ];then
    mkdir -p dump
    # ps aux > dump/pslist.txt
    # ps --no-header -eo "%p %a" | awk '{ var="cat /proc/"$1"/maps 2>/dev/null"; while( var | getline output ) {printf("%s %s \n",$1,output)}; close(var); }'>dump/allmaps.txt
    # ps --no-header -eo "%p" >dump/pid_all
    
    Pid=(`ps --no-header -eo "%p"`)
    os_type=`uname -i`
    if [ "$os_type" = "x86_64" ]
        then gdb -version&&gdbd=gdb||gdbd=gdb_static/gdb-x86-64
        else gdb -version&&gdbd=gdb||gdbd=gdb_static/gdb
    fi
    echo "gdb is $gdbd"
    for i in ${Pid[@]}
    do
        $gdbd << EOF
        attach $i
        gcore ./dump/pid_${i}.dmp
        detach
        quit
EOF
    done
else 
    PID=$1
    # Temporary file to append memory to
    TMP="`pwd`/$(date +"%Y-%m-%d")_${PID}.dump"

    # Reads memory addresses from /proc/<PID>/maps
    memory_addresses=$(grep rw-p /proc/${PID}/maps | sed -n 's/^\([0-9a-f]*\)-\([0-9a-f]*\) .*$/\1\t\2/p')

    # Inform user about acquisition
    echo -e "$(date +"%Y-%m-%d %H:%M:%S")\tStarting acquision of process ${PID}" >&2
    echo -e "$(date +"%Y-%m-%d %H:%M:%S")\tProc cmdline: \"$(cat /proc/$PID/cmdline)\"" >&2
    # Loops over the retrieved memory areas and dumps their content to a temporary file
    echo "${memory_addresses}" | while read start stop;
    do
        echo -e "$(date +"%Y-%m-%d %H:%M:%S")\tDumping $start - $stop" >&2
        os_type=`uname -i`
        if [ "$os_type" = "x86_64" ]
            then gdb_static/gdb-x86-64 --batch --pid ${PID} -ex "append memory ${TMP} 0x$start 0x$stop" >/dev/null 2>&1
            else gdb_static/gdb --batch --pid ${PID} -ex "append memory ${TMP} 0x$start 0x$stop" >/dev/null 2>&1
        fi
    done
    # Calculates the hash of the retrieved contents
    echo -e "$(date +"%Y-%m-%d %H:%M:%S")\tResulting SHA512: $(sha512sum ${TMP} | cut -d' ' -f1 -)" >&2    
fi
