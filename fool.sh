#!/bin/bash
# File tOOLkit
#
# Copyright (c) 2010    Charles Rincheval (hugo at digitalspirit dot org)
#                       http://www.digitalspirit.org/
#
# Fool is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 2 of the License,
# or (at your option) any later version.
#
# Fool is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Fool; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

# +-------------------------+
# |    Begin configuration  |
# +-------------------------+
ROOT_PATH=`cd "$(dirname $0)/../../" && pwd`
MAX_DEPTH=2
RSYNC_ARGS='-azrv --progress --compress-level=9'
# +-------------------------+
# |    End configuration    |
# +-------------------------+

# Edit only if you know what you do !

SCRIPT_PATH=`pwd`

# File read from $SCRIPT_PATH
SYNC_FILE='sync.conf'
CLEAN_FILE='clean.conf'
EXCLUDE_FILE='exclude.conf'

# Error and metadata
MD5_PATH="./meta/md5"
ERRORS_LOG="./meta/errors.log"

DATE=`date +%Y-%m-%d`
FILE_LOG="$MD5_PATH/$DATE/files.log"


VERSION=0.3
START_PATH=''

# Load hooks file
source $(dirname $0)/hook.sh
hook_start_script

START=$(date +%s)
source $(dirname $0)/include.sh


# Param
# - Path to scan
clean() {
    [[ ! -e "$SCRIPT_PATH/$CLEAN_FILE" ]] && die 1 "Conf file $CLEAN_FILE (path : $SCRIPT_PATH) don't exits !"
    while read line
    do
        process_start "Clean '$1' for '${line}'"
        find "$1" -name "$line" -exec echo "" \; -exec echo -n 'Delete: ' "{}" \; -exec rm '{}' \; 2>>"$ROOT_PATH/$ERRORS_LOG"
        process_finish $?
    done < "$SCRIPT_PATH/$CLEAN_FILE"
}

# Param :
# - Root path
# - Relative path for scan
# - Destination path
calculate_md5() {

    if [[ -a "$3" ]]; then
        confirm "Overwrite directory $3 ? (yes/no) " 'yes'
        if [ $? == "1" ]; then
            debug "Delete $ROOT_PATH/$3"
            rm -rf "$ROOT_PATH/$3"
        else
            die 0 'Cancelled by user !'
        fi
    fi

    mkdir -p $3

    SAVEIFS=$IFS; IFS=$(echo -en "\n\b")
    for path in $2
    do
        MAXDEPTH='32000'

        # Scan only file when child dir is present
        array_exists $path
        [[ $? == 1 ]] && MAXDEPTH=1

        process_start "Calculate md5 in $path dir"

        name=$path
        name=${name:2}
        name=${name//_/__}
        name=${name//\//_}
        md5sum_file="$3/$name.md5sums"
        if [ "$OS" == 'linux' ]; then
            find "$path" -maxdepth $MAXDEPTH -type f 2>>"$ROOT_PATH/$ERRORS_LOG" -exec md5sum {} \; > $md5sum_file
        elif [ "$OS" == 'macos' ]; then
            find "$path" -maxdepth $MAXDEPTH -type f 2>>"$ROOT_PATH/$ERRORS_LOG" -exec md5 -r {} \; > $md5sum_file
        fi

        process_finish $?
    done
    IFS=$SAVEIFS
}

# Param :
# - From path
# - Destination file
create_files_log() {
    process_start "Create files log in $2"
    `cat "$1"/*.md5sums 2>>"$ROOT_PATH/$ERRORS_LOG" > $2`
    process_finish $?
}

# Param :
# - Md5 file log path
check_md5() {
    [[ ! -e "$1" ]] && die 1 "$1 not found, create it now !"

    process_start "Check md5 sums"
    result=`md5sum --quiet -c "$1" 2>>"$ROOT_PATH/$ERRORS_LOG"`
    if [ -z "$result" ]; then
        process_finish $?
    else
        echo
        echo "$result"
    fi
}

# No param
check_diff() {
    cd "$MD5_PATH"

    if [[ -n "$DATE2" ]]; then
        DIRS="$DATE $DATE2"
    else
        DIRS=`ls -v | tail -n 2`
    fi

    process_start "Check integrity on $DIRS"
    result=`diff -r $DIRS`
    if [ -z "$result" ]; then
        process_finish $?
    else
        echo
        echo "$result"
    fi
}

# No param
# - Md5 file log path
scan_for_duplicate() {
    [[ ! -e "$1" ]] && die 1 "$1 not found, create it now !"

    DUPLICATE_LOG="$1.duplicate"
    echo '' > "$DUPLICATE_LOG"

    process_start "Search duplicate"

    # ToDo: Replace grep with uniq
    #uniq -d "$1" > $DUPLICATE_LOG 2>>"$ROOT_PATH/$ERRORS_LOG"
    #cat "$1" | cut -d " " -f1 | uniq -d > $DUPLICATE_LOG

    i=0

    # Scan for duplicate
    while read line
    do
        if [ $(grep -c $(echo $line|cut -d " " -f1) "$FILE_LOG") -gt 1 ]; then
            # Already in duplicate ?
            if [ $(grep -c $(echo $line|cut -d " " -f1) $DUPLICATE_LOG) -eq 0 ]; then
                ((i++))
                grep $(echo $line|cut -d " " -f1) "$1" >> $DUPLICATE_LOG
                echo '' >> $DUPLICATE_LOG
            fi
        fi
    done < "$1"

    process_finish $?

    warn "There are $i different duplicate files !"

    [[ $i > 0 ]] && cat $DUPLICATE_LOG
}

# Test if path is local or no...
# Param :
# Path
is_local() {
    local PATH=`cd "$(dirname $1)" 2> /dev/null && pwd`
    if [[ -e $PATH ]]; then
        return 1
    else
        return 0
    fi
}

# Param :
# Destination dir / host
# Local path
sync_to() {
    DESTINATION=$1
    SOURCE_PATH=$2

    # Local or remote
    is_local $DESTINATION
    #echo $?
    #exit
    if [[ $? == 1 ]]; then
        hook_start_local_rsync $DESTINATION
        debug "Source path: $SOURCE_PATH (in $ROOT_PATH); Destination path: $DESTINATION"
        confirm "Sync '$ROOT_PATH/$SOURCE_PATH' to '$DESTINATION'; method: local rsync ? (yes/no)" 'yes'
        if [[ $? == "1" ]]; then
            rsync $RSYNC_ARGS $BW_LIMIT --delete -l "$ROOT_PATH/$SOURCE_PATH" "$DESTINATION"
        else
            echo 'Cancelled by user !'
        fi
        hook_end_local_rsync $DESTINATION
    else
        hook_start_remote_rsync $DESTINATION
        debug "Source path: $SOURCE_PATH; Server: $DESTINATION;"
        confirm "Sync '$ROOT_PATH/$SOURCE_PATH' to '$DESTINATION'; method: rsync/ssh ? (yes/no)" 'yes'
        if [[ $? == "1" ]]; then
            rsync $RSYNC_ARGS $BW_LIMIT --delete -e ssh -l "$ROOT_PATH/$SOURCE_PATH" "$DESTINATION"
        else
            echo 'Cancelled by user !'
        fi
        hook_end_remote_rsync $DESTINATION
    fi
}

sync_from() {
    info 'Sync from'
    echo 'Not implemeted !'
}

# No param
size() {
    du -hs .
    du -hs *
}

usage() {
    cat <<EOF
Files toolkit
Usage: $0 [option] action

Actions :
 - clean      Clean all directories
 - md5        Calculate md5 for all file
 - duplicate  Search duplicate from md5 file
 - checkmd5   Check md5 sums
 - diff       Calculate modification between the 2 last md5 calculation (or date in arg -d / -D)
 - size       See size
 - batch      Run md5, duplicate, checkmd5 actions
 - cbatch     Same batch but clean first (clean, md5, duplicate, checkmd5)
 - sync       Synchronize
 - info       View configuration / Check for dependencies

Options :
  -v              Be verbose
  -s              Be silent
  -p ./path       Limit action to path
  -d YYYY-MM-DD   Date
  -D YYYY-MM-DD   Date (for comparison in diff action)
  -l XX           Bandwidth limit (in kB)
  -y              Non interactive mode (yes to all questions)
EOF
}

usage_sync() {
    cat <<EOF
File tOOLkit
Sync usage: $0 [option] sync action server

Server parameter must be defined in ./script/server.conf file in this way :

name#url#local path

Example :

    test#http://example.org/test/backup/#/local/dir
    test2#http://example.org/test2/backup/#/

Actions :
 - to      Sync to directory / server
 - from    Sync data from directory / server
 - list    List all configuration possible

Options :
  -v        Be verbose
  -s        Be silent
  -l XX     Bandwidth limit (in kB)
  -y        Non interactive mode (yes to all questions)
EOF
}

read_conf() {
    while read line
    do
        [[ -z $line ]] && continue
        NAME=`echo "$line" | cut -d \# -f 1`
        SERVER=`echo "$line" | cut -d \# -f 2`
        LPATH=`echo "$line" | cut -d \# -f 3`
        echo "$NAME"
        echo "  url :        $SERVER"
        echo "  local path : $LPATH"
    done < "$SCRIPT_PATH/$SYNC_FILE"
    exit 0
}

check() {
    MD5_BIN=`echo $MD5_CMD | cut -d \  -f 1`

    process_start "Check for $MD5_BIN"
    which $MD5_BIN >/dev/null 2>&1
    process_finish $? "$MD5_BIN not found !"

    process_start "Check for rsync"
    which rsync >/dev/null 2>&1
    process_finish $? 'rsync not found !'
}

information() {
    cat <<EOF
About Fool
  - Version     : $VERSION
  - Script path : $SCRIPT_PATH

Data and Metadata
  - Root path   : $ROOT_PATH
  - Md5 path    : $MD5_PATH
  - Error logs  : $ERRORS_LOG
  - File logs   : $FILE_LOG
  - Conf file   : $SYNC_FILE
  - Date        : $DATE
  - Rsync args  : $RSYNC_ARGS
  - Data paths  : 
EOF

    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    for path in $DATA_PATHS; do
        echo "    - $path"
    done
    IFS=$SAVEIFS

    cat <<EOF
  - Exclude ($EXCLUDE_FILE) : 
EOF

    while read line; do
        if [[ ${line:0:1} == '#' ]]; then
            continue
        fi
        echo "    - $line"
    done < "$SCRIPT_PATH/$EXCLUDE_FILE"

    echo "  - Os         : $OS"

    echo -n "  - Verbose    : "
    case $VERBOSE in
        0)  echo 'Silent';;
        1)  echo 'Normal';;
        2)  echo 'Verbose';;
    esac
    echo

    echo 'Dependencies :'
    echo

    local VERB=$VERBOSE
    VERBOSE=1
    check
    VERBOSE=$VERB
}

batch() {
    local cleanmode=$1

    confirm "Run batch mode ? (yes/no) : " 'yes'
    if [ $? == "1" ]; then
        START=$(date +%s)
        info 'Starting batch mode'

        if [[ $cleanmode == 1 ]]
        then
            clean "$ROOT_PATH"
            [[ $? == 1 ]] && die $? 'Error during directory cleaning !'
        fi

        calculate_md5 "$ROOT_PATH" "$DATA_PATHS" "$MD5_PATH/$DATE"
        [[ $? == 1 ]] && die $? 'Error during md5 calculation !'

        create_files_log "$MD5_PATH/$DATE" "$FILE_LOG"
        [[ $? == 1 ]] && die $? 'Error during files log creation !'

        scan_for_duplicate "$FILE_LOG"
        [[ $? == 1 ]] && die $? 'Error during duplicate searching !'

        check_md5 "$FILE_LOG"
        [[ $? == 1 ]] && die $? 'Error during md5 checking !'
    else
        die 0 'Cancelled by user !'
    fi
}

VERBOSE=1
INTERACTIVE=1

# No arg ?
[[ -z "$@" ]] && usage && exit 1

while getopts "vsyhp:l:d:D:" flag
do
  case $flag in
    v)  VERBOSE=2;;
    s)  VERBOSE=0;;
    y)  INTERACTIVE=0;;
    p)  START_PATH=$OPTARG
        debug "Set start path to $START_PATH"
        ;;
    l)  BW_LIMIT=$OPTARG
        debug "Set limit bandwith to $BW_LIMIT kB"
        ;;
    h)  usage; exit 1;;
    d)  if [[ ! "$OPTARG" =~ "[0-9]{4}-[0-9]{2}-[0-9]{2}" ]]; then
            usage
            exit 1
        fi
        DATE=$OPTARG
        debug "Set date to $DATE"
        ;;
    D)  if [[ ! "$OPTARG" =~ "[0-9]{4}-[0-9]{2}-[0-9]{2}" ]]; then
            usage
            exit 1
        fi
        DATE2=$OPTARG
        debug "Set date to $DATE2"
        ;;
    *)  usage;;
  esac
done

shift $(($OPTIND - 1))

debug "Set data root to $ROOT_PATH"
cd "$ROOT_PATH" 2>>"$ROOT_PATH/$ERRORS_LOG" || die 1 "Error while setting data root to $ROOT_PATH !"

getos


array_exists() {
    local search=$1
    local size=${#search}
    SAVEIFS=$IFS; IFS=$(echo -en "\n\b")
    for name in $DATA_PATHS; do
        [[ $name != $search && $search == ${name:0:size} ]] && return 1
    done
    IFS=$SAVEIFS
    return 0
}


load_data_dir() {

    if [[ -n $START_PATH ]]; then
        DATA_PATHS=$START_PATH
    else
        # Load exclusion list
        while read line; do
            if [[ ${line:0:1} == '#' ]]; then
                continue
            fi
            EXCLUDE="$EXCLUDE|$line"
        done < "$SCRIPT_PATH/$EXCLUDE_FILE"

        DATA_PATHS=`find . -maxdepth $MAX_DEPTH -type d -exec ls -d {} \; | grep -Ev ${EXCLUDE:1}`
    fi
}

load_data_dir

# Get action
for var in "$@"
do
    case $var in
        clean)      clean "$ROOT_PATH";;
        md5)        calculate_md5 "$ROOT_PATH" "$DATA_PATHS" "$MD5_PATH/$DATE" && create_files_log "$MD5_PATH/$DATE" "$FILE_LOG";;
        duplicate)  scan_for_duplicate "$FILE_LOG";;
        checkmd5)   check_md5 "$FILE_LOG";;
        diff)       check_diff;;
        size)       size;;
        batch)      batch;;
        cbatch)     batch 1;;
        sync)
            # Read conf file and extract data
            if [[ -n "$3" ]]; then
                SERVER=`cat "$SCRIPT_PATH/$SYNC_FILE" | grep "^$3\#" | cut -d \# -f 2`
                SOURCE_PATH=`cat "$SCRIPT_PATH/$SYNC_FILE" | grep "^$3\#" | cut -d \# -f 3`
                if [[ -z $SERVER ]]; then
                    die 1 "$3 not found in $SYNC_FILE !"
                fi
            fi

            # Read from arg command
            [[ -z "$SERVER" && "$2" != 'list' ]] && usage_sync && exit 1
            case $2 in
                to)     sync_to "$SERVER" $SOURCE_PATH;;
                from)   sync_from $SERVER;;
                list)   read_conf;;
                *)      usage_sync;
                        exit 1;;
            esac
            break
            ;;
        info)       information && exit;;
        help)       usage;;
        *)          usage; exit 1;;
    esac
done

END=$(date +%s)
DIFF=$(($END - $START))
info "Executed in $DIFF second(s)"

hook_end_script

