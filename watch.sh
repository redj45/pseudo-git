#!/bin/bash
#### main vars
t=0                                                     #set start time in minutes
user=$USER                                              #if not set - will be $USER who run script
maxfiles=24
#### functions

usage() { echo "Usage: $0 [-f <filename>] [-u <username>]" 1>&2; exit 1; }

logevt() { echo -e $(date +%F" "%T" ") $1; }

touser()
{
        echo $1 | mail -s -n -u $user
        logevt "\nSending errors message ("$1") to $USER"

}

checkfile(){

if [ $ftype == text ]
        then
                diff -s $i_file $z_file > $x_file`date +%s`
        else
                cmp $i_file $z_file -lb > $x_file`date +%s`
fi

cp $i_file $z_file && rm -rf `ls -t $x_file*| awk '{ if (NR > '$maxfiles') print; }'` && logevt "\nSave diff success"

}

######### BEGIN main script

trap 'echo "Exit"; rm -rf $lockfile; exit 1'  2 15                            #after exit - delete lock-file

#get options

while getopts "f:u:" flag
do
        case "${flag}" in
                f)
                        i_file=${OPTARG}
                        ;;
                u)
                        user=${OPTARG}
                        ;;
                *)
                        usage
                        ;;
        esac
done
shift $((OPTIND-1))

        lockfile=$i_file".lock"                                         #lock file
        dirw=$i_file"_aka_vcs"                                          #directory for 24 diff
        logfile="$dirw/$i_file.log"                                     #log file
        z_file="$dirw/$i_file.save"                                     #zero patient :)
        x_file="$dirw/$i_file.diff."

                if [ -e $lockfile ]
                then
                        logevt "Daemon already running"
                        touser "Script already running"
                        exit 1
                else

                        [ -z "${i_file}" ]  && logevt "\nPlease, enter filename into this directory" && usage ||                                 #exit, if filename is not set :(

                        [ ! -e "${i_file}" ] && logevt "\nPlease, enter exist filename into this direcroty" && usage ||                           #exit, if file is not exist :(

                        [ ! -f "${i_file}" ] && logevt "\nFile ${i_file} is not type file. His type `file ${i_file}`" && usage ||                   #exit, if file is not type file (example: directory)

                        ftype=$(file ${i_file} |sed -e 's/\.\///' -e 's/'${i_file}'\://'| grep -oE 'data|ELF|text')

                        [ -z $ftype ] && logevt "\nSorry, but $i_file is not data or text. Exit" && usage ||                                  #if it's OK, continue, else exit

                        [ -e ./$dirw ] && logevt "\nDirectory for save history already exist. \
                        Please remove exist directory or reRun script into other path" && usage ||                                              #exit, if directory is exist :(

                        #Redirect STDOUT and STDERR to log-file
                        mkdir ./$dirw
                        exec 1>>$logfile
                        exec 2>>$logfile

                        echo $$ > $lockfile
                        logevt "Starting monitor for file $i_file and create lock-file=$lockfile with PID=$$"                                          #create lock file

                        cp $i_file $z_file &&                                                                                 #if it's all OK, create directory for diff and zero patient

                        while [ : ]                                                                                                             #start monitoring file
                        do
                                sleep 5m
                                let t=$t+5
                                [ $t -le 60 ] &&
                                { if [ `md5sum $i_file |awk {'print $1'}` != `md5sum $z_file|awk {'print $1'}` ]
                                then
                                        ###start save diff
                                        checkfile &  pid=$!
                                        { sleep 10; kill $pid && touser "\nError save $i_file"; } &
                                        wait $pid
                                        ###stop save diff
                                else
                                        continue
                                fi } || t=0
                        done

                fi
