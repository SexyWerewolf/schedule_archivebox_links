#!/bin/bash

# Script Made By Dachi Wolf
# https://github.com/SexyWerewolf

# Define paths
LINKS_SCRIPT="$HOME/archivebox/auto_archive_links/links.sh"
LOG_FILE="$HOME/archivebox/auto_archive_links/logs.log"

# Write logs
echo "Running link processing at $(date)" >> "$LOG_FILE"

# Execute the links.sh script
if [ -x "$LINKS_SCRIPT" ]; then
    "$LINKS_SCRIPT"
else
    echo "Error: $LINKS_SCRIPT is not executable or does not exist" >> "$LOG_FILE"
fi

# Log completion
echo "Link processing completed at $(date)" >> "$LOG_FILE"