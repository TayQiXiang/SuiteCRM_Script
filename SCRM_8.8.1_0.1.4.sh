#!/bin/bash

# --- Script to install SuiteCRM 8 on a Debian/Ubuntu based system ---

# Function to request user input with a default value
get_input() {
    local prompt="$1"
    local default_value="$2"
    local variable_name="$3"
    local value
    read -p "$prompt [$default_value]: " value
    # Assign the user's input or the default value if input is empty
    eval "$variable_name='${value:-$default_value}'"
}

# Function to automatically get the internal IP
get_internal_ip() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127' | head -n1
}

# --- User Information ---
echo "--- Database and Port Configuration ---"
get_input "Enter your MariaDB username" "suitecrm_user" db_user
get_input "Enter your MariaDB password" "StrongPassword123" db_pass
get_input "Enter the port for SuiteCRM (Apache)" "80" apache_port
get_input "Enter the port for MariaDB" "3306" mariadb_port
echo "---------------------------------------"
echo

# Automatically get the internal IP
server_ip=$(get_internal_ip)
echo "IP retrieved: $server_ip"

# --- System & Package Installation ---
echo "Updating and installing essential packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install unzip wget -y

# Update and install PHP packages from PPA for latest versions
echo "Updating and installing PHP packages..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install php8.2 libapache2-mod-php8.2 php8.2-cli php8.2-common php8.2-curl php8.2-gd php8.2-imap php8.2-intl php8.2-ldap php8.2-mbstring php8.2-mysql php8.2-pdo php8.2-soap php8.2-xml php8.2-zip php8.2-bcmath -y

# --- MariaDB Configuration ---
echo "Installing MariaDB..."
sudo apt install mariadb-server mariadb-client -y

# Configure MariaDB to listen on the specified port
MARIADB_CONFIG_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"
echo "Configuring MariaDB to use port $mariadb_port..."
if [ -f "$MARIADB_CONFIG_FILE" ]; then
    # Remove existing port setting if it exists
    sudo sed -i '/^port\s*=/d' "$MARIADB_CONFIG_FILE"
    # Add the new port setting under the [mysqld] section
    sudo sed -i "/\[mysqld\]/a port = $mariadb_port" "$MARIADB_CONFIG_FILE"
else
    echo "Warning: MariaDB config file not found at $MARIADB_CONFIG_FILE. Could not set custom port."
fi

# Start and enable MariaDB service to apply changes
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo systemctl restart mariadb

# Configure database and user
echo "Configuring main database..."
# Note: Using localhost connects via socket, bypassing the TCP port for this setup script.
# The web application will connect via TCP using the specified port.
sudo mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS CRM CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
GRANT ALL PRIVILEGES ON CRM.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# Verify database creation
if sudo mysql -u root -e "USE CRM"; then
    echo "Database 'CRM' created successfully."
else
    echo "Failed to create database 'CRM'. Please check permissions."
    exit 1
fi

# Verify user creation
if sudo mysql -u root -e "SELECT User FROM mysql.user WHERE User='$db_user';" | grep -q "$db_user"; then
    echo "User '$db_user' created successfully."
else
    echo "Failed to create user '$db_user'. Please check permissions."
    exit 1
fi

# --- Apache Configuration ---
echo "Configuring Apache Server..."
sudo a2enmod rewrite

# Tell Apache to listen on the new port if it's not the default
if [[ "$apache_port" != "80" ]] && ! grep -q "^Listen $apache_port" /etc/apache2/ports.conf; then
    echo "Adding 'Listen $apache_port' to Apache configuration."
    echo "Listen $apache_port" | sudo tee -a /etc/apache2/ports.conf
fi

# Disable directory listing globally for security
echo "Disabling directory listing globally..."
cat << EOF | sudo tee /etc/apache2/conf-available/disable-directory-listing.conf
<Directory /var/www/>
    Options -Indexes
</Directory>
EOF
sudo a2enconf disable-directory-listing

# Configure VirtualHost for SuiteCRM
echo "Configuring VirtualHost..."
cat << EOF | sudo tee /etc/apache2/sites-available/crm.conf
<VirtualHost *:$apache_port>
    ServerAdmin admin@example.com
    DocumentRoot /var/www/html/crm/public
    ServerName $server_ip
    <Directory /var/www/html/crm/public>
        Options -Indexes +FollowSymLinks +MultiViews
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/crm_error.log
    CustomLog \${APACHE_LOG_DIR}/crm_access.log combined
</VirtualHost>
EOF
sudo a2ensite crm.conf

#Disable apache default entry page
sudo a2dissite 000-default.conf

sudo systemctl restart apache2

# --- SuiteCRM Installation ---
echo "Installing and configuring SuiteCRM..."

# Clean up previous SuiteCRM installation if it exists
echo "Cleaning up any previous SuiteCRM installation..."
sudo rm -rf /var/www/html/crm

cd /var/www/html
sudo mkdir crm
cd /var/www/html/crm
# Using a known stable version. You can update the URL for a newer version.
sudo wget https://suitecrm.com/download/165/suite88/565368/suitecrm-8-8-1.zip -O suitecrm.zip
sudo unzip suitecrm.zip
sudo rm suitecrm.zip

# --- PHP & File Permissions ---
echo "Configuring php.ini settings..."
PHP_INI_PATH="/etc/php/8.2/apache2/php.ini"
sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' "$PHP_INI_PATH"
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 50M/' "$PHP_INI_PATH"
sudo sed -i 's/post_max_size = .*/post_max_size = 50M/' "$PHP_INI_PATH"
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI_PATH"

echo "Adjusting SuiteCRM file permissions..."
sudo chown -R www-data:www-data /var/www/html/crm
sudo find /var/www/html/crm -type d -exec chmod 2755 {} \;
sudo find /var/www/html/crm -type f -exec chmod 0644 {} \;
sudo chmod +x /var/www/html/crm/bin/console

# Restart Apache to apply all changes
sudo systemctl restart apache2

# --- Final Instructions ---
echo
echo "========================================================================"
echo "✅ Script Finished!"
echo "========================================================================"
echo
echo "IMPORTANT: Before proceeding, run the security script for MariaDB:"
echo "  sudo mysql_secure_installation"
echo
echo "You can now complete the installation in your web browser."
echo "  URL: http://$server_ip:$apache_port"
echo
echo "During the web installation, use the following database settings:"
echo "  Database Name: CRM"
echo "  Database Host: localhost:$mariadb_port"
echo "  Database User: $db_user"
echo "  Database Pass: [the password you entered]"
echo
echo "Enjoy your new SuiteCRM installation!"
echo "========================================================================"