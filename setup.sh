#!/bin/bash

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne "0" ]; then
    echo "This script must be run as root."
    exit 1
fi

# Define paths
USER_BIN_DIR="$HOME/bin"
BOXADD_PATH="/usr/local/bin/boxadd"
AUTO_ARCHIVE_LINKS_DIR="$HOME/archivebox/auto_archive_links"
LINKS_FILE="$AUTO_ARCHIVE_LINKS_DIR/links.sh"
LOGS_FILE="$AUTO_ARCHIVE_LINKS_DIR/logs.log"
RUN_SCRIPT_PATH="$AUTO_ARCHIVE_LINKS_DIR/run-script.sh"

# Function to create the boxadd script
create_boxadd_script() {
    echo "#!/bin/bash

# Check if URL argument is provided
if [ -z \"\$1\" ]; then
    echo \"Usage: boxadd <URL>\"
    exit 1
fi

URL=\"\$1\"
DOMAIN=\$(echo \"\$URL\" | awk -F[/:] '{print \$4}')

# Define paths
LINKS_FILE=\"$AUTO_ARCHIVE_LINKS_DIR/links.sh\"
LOG_FILE=\"$AUTO_ARCHIVE_LINKS_DIR/logs.log\"

# Function to add URL to the links.sh file
add_url() {
    local url=\"\$1\"
    
    # Append the URL
    echo \"docker exec --user=archivebox archivebox-archivebox-1 archivebox add '\$url'\" >> \"\$LINKS_FILE\"
}

# Add URL to links.sh
add_url \"\$URL\"

# Log URL addition
echo \"Added URL: \$URL\" >> \"\$LOG_FILE\"
" | tee "$BOXADD_PATH" > /dev/null

    chmod +x "$BOXADD_PATH"
    echo "Created boxadd script at $BOXADD_PATH"
}

# Function to create directories and files
create_directories_and_files() {
    if [ -d "$AUTO_ARCHIVE_LINKS_DIR" ]; then
        echo "Directory $AUTO_ARCHIVE_LINKS_DIR already exists."
        
        # Prompt for reset
        read -p "Do you want to reset the data in links.sh and logs.log? (y/n): " RESET
        if [ "$RESET" == "y" ]; then
            echo -e "\n# Resetting links.sh and logs.log..."
            echo -n "" > "$LINKS_FILE"   # Clear links.sh
            echo -n "" > "$LOGS_FILE"    # Clear logs.log
        fi
    else
        echo "Creating directory $AUTO_ARCHIVE_LINKS_DIR..."
        mkdir -p "$AUTO_ARCHIVE_LINKS_DIR"
        
        echo "Creating $LINKS_FILE..."
        touch "$LINKS_FILE"
        
        echo "Creating $LOGS_FILE..."
        touch "$LOGS_FILE"
    fi
    
    echo "Creating run-script.sh..."
    echo "#!/bin/bash

# Define paths
LINKS_FILE=\"$LINKS_FILE\"
LOG_FILE=\"$LOGS_FILE\"

# Write logs
echo \"Running archive job at \$(date)\" >> \"\$LOG_FILE\"

# Read and execute each line in the script file
while IFS= read -r line; do
    if [[ \$line == docker* ]]; then
        url=\$(echo \"\$line\" | awk -F\"'\" '{print \$2}')
        echo \"Adding URL: \$url\" >> \"\$LOG_FILE\"
        eval \"\$line\"
        if [ \$? -eq 0 ]; then
            echo \"Successfully archived: \$url\" >> \"\$LOG_FILE\"
        else
            echo \"Failed to archive: \$url\" >> \"\$LOG_FILE\"
        fi
    else
        echo \"\$line\"
    fi
done < \"$LINKS_FILE\"

# Log completion
echo \"Archive job completed at \$(date)\" >> \"\$LOG_FILE\"
" > "$RUN_SCRIPT_PATH"
    chmod +x "$RUN_SCRIPT_PATH"
    echo "Created run-script.sh at $RUN_SCRIPT_PATH"
}

# Function to setup the cron job
setup_cron() {
    local valid_hours=0
    local CRON_JOBS=""
    
    while [ $valid_hours -eq 0 ]; do
        echo "Enter the hours (24-hour format) for the cron job, separated by periods (e.g., 18 for 6 PM):"
        read -p "Enter the hours: " HOURS

        # Prepare cron jobs
        IFS='.' read -r -a TIME_ARRAY <<< "$HOURS"
        CRON_JOBS=""
        
        for TIME in "${TIME_ARRAY[@]}"; do
            # Validate the hour
            if [[ "$TIME" =~ ^[0-9]+$ ]] && [ "$TIME" -ge 0 ] && [ "$TIME" -le 23 ]; then
                # Use hours only, default minutes to 0
                HOUR=${TIME}

                # Add to cron jobs only if not already present
                if [[ ! "$CRON_JOBS" =~ "0 $HOUR * * *" ]]; then
                    CRON_JOBS+="0 $HOUR * * * $RUN_SCRIPT_PATH "
                fi
            else
                echo "Invalid hour: $TIME. Please enter hours between 0 and 23."
                CRON_JOBS=""
                break
            fi
        done

        # Check if CRON_JOBS is valid
        if [ -n "$CRON_JOBS" ]; then
            valid_hours=1
        else
            echo "Please enter valid hours."
        fi
    done

    # Remove trailing space
    CRON_JOBS=$(echo "$CRON_JOBS" | sed 's/ $//')

    # Clear existing cron jobs related to this script
    crontab -l | grep -v "$RUN_SCRIPT_PATH" | crontab -

    # Add the new cron jobs
    if [ -n "$CRON_JOBS" ]; then
        (crontab -l 2>/dev/null; echo "$CRON_JOBS") | crontab -
        echo "Cron job(s) added: $CRON_JOBS"
    else
        echo "No valid hours provided. No cron jobs added."
    fi
}

# Main script logic
echo "Starting setup..."

create_boxadd_script
create_directories_and_files

# Prompt to enable cron job
read -p "Do you want to enable the cron job? (y/n): " ENABLE_CRON
if [ "$ENABLE_CRON" == "y" ]; then
    setup_cron
else
    echo "Cron job not enabled. No cron job will be set up."
fi

echo "Setup complete."
