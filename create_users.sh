#!/bin/bash

# Absolute paths for files
input_file="/hng/username.txt"  # Update with correct path to username.txt
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"  # Update with correct secure location

# Function to generate random password
generate_password() {
    local password_length=12
    local password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c $password_length)
    echo "$password"
}

# Function to log messages
log_message() {
    local log_timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "$log_timestamp - $1" >> "$log_file"
}

# Function to check and create groups
check_and_create_group() {
    local group="$1"
    if ! getent group "$group" >/dev/null; then
        sudo groupadd "$group"
        log_message "Group '$group' created."
    fi
}

# Function to create personal group for user
create_personal_group() {
    local username="$1"
    if ! getent group "$username" >/dev/null; then
        sudo groupadd "$username"
        log_message "Personal group '$username' created for user '$username'."
    fi
}

# Function to securely store password
store_password_securely() {
    local username="$1"
    local password="$2"
    echo "$username:$password" | sudo tee -a "$password_file" > /dev/null
    sudo chmod 600 "$password_file"
    sudo chown root:root "$password_file"
    log_message "Password for user '$username' stored securely."
}

# Check if input file exists
if [ ! -f "$input_file" ]; then
    log_message "Error: $input_file not found. Exiting script."
    exit 1
fi

# Create log file if it doesn't exist
if [ ! -f "$log_file" ]; then
    sudo touch "$log_file"
    sudo chmod 644 "$log_file"
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

    # Check if user already exists
    if id -u "$username" >/dev/null 2>&1; then
        log_message "User '$username' already exists. Skipping."
        continue
    fi

    # Create personal group for user
    create_personal_group "$username"

    # Check if groups exist and create them if they don't
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        check_and_create_group "$group"
    done

    # Generate random password
    password=$(generate_password)

    # Create user with specified groups and set password
    sudo useradd -m -s /bin/bash -G "$groups,$username" "$username" >> "$log_file" 2>&1
    echo "$username:$password" | sudo chpasswd >> "$log_file" 2>&1

    if [ $? -eq 0 ]; then
        log_message "User '$username' created with groups: $groups."
        store_password_securely "$username" "$password"
    else
        log_message "Failed to create user '$username'."
    fi

done < "$input_file"

log_message "User creation process completed."

echo "User creation process completed. Check $log_file for details."
