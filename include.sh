#!/bin/bash

debug() {
    STATUS=$1
    [[ $VERBOSE && $VERBOSE == 2 ]] && echo "[debug] $STATUS"
}

info() {
    STATUS=$1
    [[ $VERBOSE && $VERBOSE > 0 ]] && echo "[info]  $STATUS"
}

warn() {
    STATUS=$1
    [[ $VERBOSE && $VERBOSE > 0 ]] && echo "[warn]  $STATUS"
}

error() {
    echo "[error] $1"
}

process_start() {
    STATUS=$1
    [[ $VERBOSE && $VERBOSE > 0 ]] && echo -n $STATUS
}

process_finish() {
    STATUS=$1
    if [[ $VERBOSE && $VERBOSE > 0 ]]; then
        if [[ $STATUS -ne 0 ]]; then

            if [[ -n "$2" ]]; then
                LAST_ERROR=$2
            else
                LAST_ERROR=`tail -n 1 $ERRORS_LOG`
            fi

            echo " [error] : $LAST_ERROR"
            exit 1
        else
            process_success
        fi
    fi
}

process_success() {
    [[ $VERBOSE && $VERBOSE > 0 ]] && echo " [ok]"
}

die() {
    echo $2
    exit $1
}

confirm() {
    [[ $INTERACTIVE == 0 ]] && return 1

    if [[ $VERBOSE && $VERBOSE > 0 ]]; then
        local answer
        echo -n "$1 "
        read -e answer

        if [ "$answer" == $2 ]; then
            return 1
        else
            return 0
        fi
    else
        return 1
    fi
}

OS='?'
MD5_CMD='md5sum'
getos() {
    case `uname` in
        'Linux')    OS='linux';;
        'Darwin')   OS='macos'; MD5_CMD='md5 -r';;
        CYGWIN* )   OS='linux';;
    esac
    debug "Os set to $OS"
}

