#!/bin/bash
# Absolute paths for files
input_file="$1"
log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.csv"
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi
# Check if the input file is provided as an argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <name-of-text-file>"
  exit 1
fi
# Function to generate a random password
generate_password() {
  local password_length=12
  local password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c $password_length)
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
  touch "$log_file"
  chmod 644 "$log_file"
  log_message "Log file created: $log_file"
fi
# Create password file if it doesn't exist
if [ ! -f "$password_file" ]; then
  touch "$password_file"
  chmod 600 "$password_file"
  chown root:root "$password_file"
  log_message "Password file created: $password_file"
fi
# Clear existing content in password file (if any)
truncate -s 0 "$password_file"
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
  # Create user's personal group if it doesn't exist
  if ! getent group "$username" >/dev/null; then
    groupadd "$username"
    log_message "Group '$username' created."
  fi
  # Create additional groups if they don't exist
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    if ! getent group "$group" >/dev/null; then
      groupadd "$group"
      log_message "Group '$group' created."
    fi
  done
  # Generate random password
  password=$(generate_password)
  # Create user with specified groups, including the personal group, and set password
  useradd -m -s /bin/bash -g "$username" -G "$username,$groups" "$username" >> "$log_file" 2>&1
  echo "$username:$password" | chpasswd >> "$log_file" 2>&1
  if [ $? -eq 0 ]; then
    log_message "User '$username' created with groups: $groups. Password set."
    echo "$username,$password" >> "$password_file"
  else
    log_message "Failed to create user '$username'."
  fi
  # Set correct permissions for the home directory
  chown "$username:$username" "/home/$username"
  chmod 700 "/home/$username"
done < "$input_file"
log_message "User creation process completed."
echo "User creation process completed. Check $log_file for details."
