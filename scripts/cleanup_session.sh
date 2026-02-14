#!/bin/bash
# SessionEnd hook — clean up session state directory
source "$(dirname "$0")/common.sh"
init_hook

# Remove the entire session directory
rm -rf "$STATE_DIR"
exit 0
