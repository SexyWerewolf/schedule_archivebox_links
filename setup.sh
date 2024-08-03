#!/bin/bash

# Script Made By Dachi Wolf
# https://github.com/SexyWerewolf

# Color definitions for better appearance
COLOR_RESET="\033[0m"
COLOR_BOLD="\033[1m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne "0" ]; then
    echo -e "${COLOR_RED}This script must be run as root.${COLOR_RESET}"
    exit 1
fi

# Get the actual user running the script
if [ -z "$SUDO_USER" ]; then
    echo -e "${COLOR_RED}This script must be run with sudo.${COLOR_RESET}"
    exit 1
fi

USER_HOME=$(eval echo ~${SUDO_USER})

# Define paths
USER_BIN_DIR="$USER_HOME/bin"
BOXADD_PATH="/usr/local/bin/boxadd"
AUTO_ARCHIVE_LINKS_DIR="$USER_HOME/archivebox/auto_archive_links"
LINKS_FILE="$AUTO_ARCHIVE_LINKS_DIR/links.sh"
LOGS_FILE="$AUTO_ARCHIVE_LINKS_DIR/logs.log"
RUN_SCRIPT_PATH="$AUTO_ARCHIVE_LINKS_DIR/run-script.sh"

# Function to create the boxadd script
create_boxadd_script() {
    echo -e "${COLOR_GREEN}Creating boxadd script...${COLOR_RESET}"
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
    chown "$SUDO_USER:$SUDO_USER" "$BOXADD_PATH"
    echo -e "${COLOR_GREEN}Created boxadd script at $BOXADD_PATH${COLOR_RESET}"
}

# Function to create directories and files
create_directories_and_files() {
    echo -e "${COLOR_GREEN}Setting up directories and files...${COLOR_RESET}"
    if [ -d "$AUTO_ARCHIVE_LINKS_DIR" ]; then
        echo -e "${COLOR_YELLOW}Directory $AUTO_ARCHIVE_LINKS_DIR already exists.${COLOR_RESET}"
        
        # Prompt for reset
        read -p "Do you want to reset the data in links.sh and logs.log? (y/n): " RESET
        if [ "$RESET" == "y" ]; then
            echo -e "\n${COLOR_YELLOW}Resetting links.sh and logs.log...${COLOR_RESET}"
            echo -n "" > "$LINKS_FILE"   # Clear links.sh
            echo -n "" > "$LOGS_FILE"    # Clear logs.log
        fi
    else
        echo -e "${COLOR_GREEN}Creating directory $AUTO_ARCHIVE_LINKS_DIR...${COLOR_RESET}"
        mkdir -p "$AUTO_ARCHIVE_LINKS_DIR"
        chown "$SUDO_USER:$SUDO_USER" "$AUTO_ARCHIVE_LINKS_DIR"
        
        echo -e "${COLOR_GREEN}Creating $LINKS_FILE...${COLOR_RESET}"
        touch "$LINKS_FILE"
        chown "$SUDO_USER:$SUDO_USER" "$LINKS_FILE"
        
        echo -e "${COLOR_GREEN}Creating $LOGS_FILE...${COLOR_RESET}"
        touch "$LOGS_FILE"
        chown "$SUDO_USER:$SUDO_USER" "$LOGS_FILE"
    fi
    echo -e "${COLOR_GREEN}Creating run-script.sh...${COLOR_RESET}"
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
    chown "$SUDO_USER:$SUDO_USER" "$RUN_SCRIPT_PATH"
    echo -e "${COLOR_GREEN}Created run-script.sh at $RUN_SCRIPT_PATH${COLOR_RESET}"
}

# Function to setup the cron job
setup_cron() {
    while true; do
        echo -e "${COLOR_GREEN}Enter the hours (24-hour format) for the cron job, separated by periods (e.g., 18 for 6 PM):${COLOR_RESET}"
        read -p "Enter the hours: " HOURS
        # Prepare cron jobs
        CRON_JOBS=""
        IFS='.' read -r -a TIME_ARRAY <<< "$HOURS"
        valid_hours=true
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
                echo -e "${COLOR_RED}Invalid hour: $TIME. Please enter hours between 0 and 23.${COLOR_RESET}"
                valid_hours=false
                break
            fi
        done
        if [ "$valid_hours" == true ]; then
            break
        fi
    done
    # Remove trailing space
    CRON_JOBS=$(echo "$CRON_JOBS" | sed 's/ $//')
    # Clear existing cron jobs related to this script
    crontab -u "$SUDO_USER" -l | grep -v "$RUN_SCRIPT_PATH" | crontab -u "$SUDO_USER" -
    # Add the new cron jobs
    if [ -n "$CRON_JOBS" ]; then
        (crontab -u "$SUDO_USER" -l 2>/dev/null; echo "$CRON_JOBS") | crontab -u "$SUDO_USER" -
        echo -e "${COLOR_GREEN}Cron job(s) added: $CRON_JOBS${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}No valid hours provided. No cron jobs added.${COLOR_RESET}"
    fi
}

# Main script logic
echo -e "${COLOR_BOLD}Starting setup...${COLOR_RESET}"
create_boxadd_script
create_directories_and_files
# Prompt to enable cron job
read -p "Do you want to enable the cron job? (y/n): " ENABLE_CRON
if [ "$ENABLE_CRON" == "y" ]; then
    setup_cron
else
    echo -e "${COLOR_YELLOW}Cron job not enabled. No cron job will be set up.${COLOR_RESET}"
fi

# Final message showing the main location of the script
echo 
echo -e "${COLOR_BOLD}Setup complete.${COLOR_RESET}"
echo
echo -e "\n${COLOR_CYAN}${COLOR_BOLD}=====================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}Main location of the script:${COLOR_GREEN} $AUTO_ARCHIVE_LINKS_DIR${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}=====================================================${COLOR_RESET}"
