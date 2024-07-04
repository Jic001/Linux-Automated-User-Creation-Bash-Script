#!/bin/bash

# Paths for files (Adjustments for review)
input_file="$1"
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

# Check if the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if the input file is provided as an argument and direct on what to do if input file is not provided
if [ $# -ne 1 ]; then
  echo "Please run this instead: $0 <name-of-text-file>"
  exit 1
fi

#(Adjustment. )
# Function to generate random password
generate_password() {
    local password_length=12
    local password=$(head /dev/urandom | tr -dc '[:alnum:]' | head -c $password_length)
    echo "$password"
}

# Function to log messages
log_message() {
    local log_timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "$log_timestamp - $1" >> "$log_file"
}

# Check if input file exists
if [ ! -f "$input_file" ]; then
    log_message "Error: $input_file not found. Exiting script."
    exit 1
fi

# Create log file if it doesn't exist
if [ ! -f "$log_file" ]; then
    sudo touch "$log_file"
    sudo chmod 640 "$log_file"
    log_message "Log file created: $log_file"
fi

# Create password file if it doesn't exist
if [ ! -f "$password_file" ]; then
    sudo touch "$password_file"
    sudo chmod 600 "$password_file"
    sudo chown root:root "$password_file"
    log_message "Password file created: $password_file"
fi

# Clear existing content in password file (if any)
sudo truncate -s 0 "$password_file"

# Read each line from input file
while IFS=';' read -r username groups; do
    # Trim leading and trailing whitespace from username and groups
    username=$(echo "$username" | tr -d '[:space:]')
    groups=$(echo "$groups" | tr -d '[:space:]')

    # Generate random password
    password=$(generate_password)

    # Create user with personal group if user does not exist
    if ! id -u "$username" >/dev/null 2>&1; then
        sudo useradd -m -s /bin/bash -G "$groups" "$username" >> "$log_file" 2>&1
        echo "$username:$password" | sudo chpasswd >> "$log_file" 2>&1
        if [ $? -eq 0 ]; then
            log_message "User '$username' created with groups: $groups. Password set."
            echo "$username,$password" | sudo tee -a "$password_file" > /dev/null
        else
            log_message "Failed to create user '$username'."
            continue
        fi
    else
        log_message "User '$username' already exists. Adding to specified groups."
    fi

    # Create groups if they don't exist and add user to them
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" >/dev/null; then
            sudo groupadd "$group"
            log_message "Group '$group' created."
        fi
        sudo usermod -aG "$group" "$username" >> "$log_file" 2>&1
    done

    # Ensure user is in their personal group
    sudo usermod -g "$username" "$username" >> "$log_file" 2>&1

done < "$input_file"

log_message "User creation process completed."

echo "User creation process completed. Check $log_file for details."
