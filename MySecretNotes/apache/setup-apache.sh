#!/bin/bash

################################################################################
# Apache Deployment Script for My Secret Notes Flask Application
################################################################################
#
# This script automates the deployment of the Flask application with Apache
# on Ubuntu 20.04.
#
# Usage:
#   sudo ./setup-apache.sh [APP_DIRECTORY]
#
# Examples:
#   sudo ./setup-apache.sh                          # Uses current directory
#   sudo ./setup-apache.sh /var/www/MySecretNotes   # Uses specified directory
#
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration Variables (easy to modify)
################################################################################

# Get the script's directory and use parent directory as default APP_DIR
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEFAULT_APP_DIR="$(dirname "$SCRIPT_DIR")"

# App directory - use argument if provided, otherwise use parent directory
if [ -z "$1" ]; then
    APP_DIR="$DEFAULT_APP_DIR"
    echo -e "${YELLOW}No directory specified. Using project directory: $APP_DIR${NC}"
else
    APP_DIR="$1"
    # Convert to absolute path
    APP_DIR="$(cd "$APP_DIR" && pwd)"
fi

# Site configuration name
SITE_NAME="mysecretnotesapp"

# Apache configuration files
APACHE_CONFIG_SOURCE="$APP_DIR/apache/apache-config-example.conf"
APACHE_CONFIG_DEST="/etc/apache2/sites-available/$SITE_NAME.conf"

# Log files
ERROR_LOG="/var/log/apache2/$SITE_NAME-error.log"
ACCESS_LOG="/var/log/apache2/$SITE_NAME-access.log"

################################################################################
# Helper Functions
################################################################################

print_step() {
    echo -e "\n${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_ubuntu() {
    if [ ! -f /etc/lsb-release ]; then
        print_warning "This script is designed for Ubuntu. It may not work on other distributions."
    fi
}

check_app_directory() {
    if [ ! -d "$APP_DIR" ]; then
        print_error "Directory does not exist: $APP_DIR"
        exit 1
    fi
    
    if [ ! -f "$APP_DIR/app.py" ]; then
        print_error "app.py not found in $APP_DIR"
        exit 1
    fi
    
    if [ ! -f "$APACHE_CONFIG_SOURCE" ]; then
        print_error "apache-config-example.conf not found in $APP_DIR/apache/"
        exit 1
    fi
}

################################################################################
# Main Installation Steps
################################################################################

main() {
    echo "################################################################################"
    echo "# Apache Deployment Script for My Secret Notes"
    echo "################################################################################"
    echo ""
    echo "Application Directory: $APP_DIR"
    echo "Configuration Name: $SITE_NAME"
    echo ""
    
    # Perform checks
    check_root
    check_ubuntu
    check_app_directory
    
    # Step 1: Install required software
    print_step "Step 1: Installing required software (apache2, mod-wsgi, python3-pip)"
    apt update
    apt install -y apache2 libapache2-mod-wsgi-py3 python3-pip
    
    # Step 2: Install Python dependencies
    print_step "Step 2: Installing Python dependencies (Flask)"
    cd "$APP_DIR"
    if [ -f requirements.txt ]; then
        print_step "Found requirements.txt, installing all dependencies"
        pip3 install -r requirements.txt
    else
        pip3 install flask
    fi
    
    # Step 3: Configure Apache
    print_step "Step 3: Configuring Apache"
    
    # Update the configuration file with the correct paths
    print_step "Creating Apache configuration with correct paths"
    sed "s|/home/student/MySecretNotes|$APP_DIR|g" "$APACHE_CONFIG_SOURCE" > "$APACHE_CONFIG_DEST"
    
    # Also update the site name in logs if present
    sed -i "s|mysecretnotesapp|$SITE_NAME|g" "$APACHE_CONFIG_DEST"
    
    print_step "Enabling the site: $SITE_NAME"
    a2ensite "$SITE_NAME.conf"
    
    print_step "Enabling mod_wsgi"
    a2enmod wsgi
    
    print_step "Disabling default site (optional)"
    if a2query -s 000-default.conf &>/dev/null; then
        a2dissite 000-default.conf
    fi
    
    # Step 4: Set proper permissions
    print_step "Step 4: Setting proper permissions"
    
    print_step "Setting ownership to www-data"
    chown -R www-data:www-data "$APP_DIR"
    
    print_step "Setting directory permissions"
    chmod 775 "$APP_DIR"
    
    if [ -f "$APP_DIR/db.sqlite3" ]; then
        print_step "Setting database file permissions"
        chmod 664 "$APP_DIR/db.sqlite3"
    else
        print_warning "Database file db.sqlite3 not found. It will be created when the app runs."
    fi
    
    # Step 5: Test configuration
    print_step "Step 5: Testing Apache configuration"
    if apache2ctl configtest; then
        echo -e "${GREEN}Configuration test passed!${NC}"
    else
        print_error "Configuration test failed. Please check the error messages above."
        exit 1
    fi
    
    # Step 6: Restart Apache
    print_step "Step 6: Restarting Apache"
    systemctl restart apache2
    
    print_step "Checking Apache status"
    systemctl status apache2 --no-pager
    
    # Final instructions
    echo ""
    echo "################################################################################"
    echo -e "${GREEN}# Installation Complete!${NC}"
    echo "################################################################################"
    echo ""
    echo "Your application should now be running!"
    echo ""
    echo "Access it at:"
    echo "  - http://localhost"
    echo "  - http://your-server-ip"
    echo ""
    echo "Troubleshooting:"
    echo "  - View error log: sudo tail -f $ERROR_LOG"
    echo "  - View access log: sudo tail -f $ACCESS_LOG"
    echo "  - Check Apache status: sudo systemctl status apache2"
    echo "  - Restart Apache: sudo systemctl restart apache2"
    echo ""
    echo -e "${YELLOW}SECURITY WARNING:${NC}"
    echo "This application has known security vulnerabilities (SQL injection, etc.)"
    echo "Do NOT use in production without addressing these issues!"
    echo ""
}

# Run main function
main

