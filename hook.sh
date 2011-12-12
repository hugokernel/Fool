#!/bin/bash

# Script start
hook_start_script() {
    nop=1 
}

# Script stop
hook_end_script() {
    nop=1 
}

# Param :
# - Source path
# - Destination path
hook_start_local_rsync() {
    if [[ $OS == 'macos' ]]; then
        # Disable spotlight indexing
        mdutil -i off "$2" > /dev/null
    fi
}

# Param :
# - Source path
# - Destination path
hook_end_local_rsync() {
    if [[ $OS == 'macos' ]]; then
        # Re-enable spotlight indexing
        mdutil -i on "$2" > /dev/null
    fi
}

# Param :
# - Source path
# - Destination path
hook_start_remote_rsync() {
    nop=1 
}

# Param :
# - Source path
# - Destination path
hook_end_remote_rsync() {
    nop=1 
}

