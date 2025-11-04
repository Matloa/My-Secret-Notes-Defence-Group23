#!/bin/bash

################################################################################
# Apache SSL/TLS Setup Script for My Secret Notes Flask Application
################################################################################
#
# This script sets up SSL/TLS (HTTPS) for your Apache deployment.
# It supports both Let's Encrypt certificates and self-signed certificates.
#
# Usage:
#   sudo ./setup-apache-ssl.sh [OPTIONS] [APP_DIRECTORY]
#
# Options:
#   --letsencrypt DOMAIN    Use Let's Encrypt for domain (e.g., example.com)
#   --selfsigned           Use self-signed certificate (default, for testing)
#
# Examples:
#   sudo ./setup-apache-ssl.sh --selfsigned                    # Self-signed cert, current dir
#   sudo ./setup-apache-ssl.sh --selfsigned /var/www/MyApp     # Self-signed cert, custom dir
#   sudo ./setup-apache-ssl.sh --letsencrypt example.com       # Let's Encrypt for example.com
#   sudo ./setup-apache-ssl.sh --letsencrypt example.com /var/www/MyApp
#
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default Configuration Variables
################################################################################
USE_LETSENCRYPT=false
DOMAIN=""
APP_DIR=""
SITE_NAME="mysecretnotesapp"
CERT_NAME="mysecretnotesapp-selfsigned"

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

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

show_usage() {
    echo "Usage: sudo $0 [OPTIONS] [APP_DIRECTORY]"
    echo ""
    echo "Options:"
    echo "  --letsencrypt DOMAIN    Use Let's Encrypt for domain"
    echo "  --selfsigned           Use self-signed certificate (default)"
    echo ""
    echo "Examples:"
    echo "  sudo $0 --selfsigned"
    echo "  sudo $0 --selfsigned /var/www/MyApp"
    echo "  sudo $0 --letsencrypt example.com"
    echo "  sudo $0 --letsencrypt example.com /var/www/MyApp"
    exit 1
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --letsencrypt)
                USE_LETSENCRYPT=true
                DOMAIN="$2"
                shift 2
                ;;
            --selfsigned)
                USE_LETSENCRYPT=false
                shift
                ;;
            --help|-h)
                show_usage
                ;;
            *)
                if [ -z "$APP_DIR" ]; then
                    APP_DIR="$1"
                else
                    print_error "Unknown argument: $1"
                    show_usage
                fi
                shift
                ;;
        esac
    done
    
    # Set default app directory if not provided
    if [ -z "$APP_DIR" ]; then
        # Get the script's directory and use parent directory as default
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        APP_DIR="$(dirname "$SCRIPT_DIR")"
    else
        # Convert to absolute path
        APP_DIR="$(cd "$APP_DIR" && pwd)"
    fi
    
    # Validate Let's Encrypt setup
    if [ "$USE_LETSENCRYPT" = true ] && [ -z "$DOMAIN" ]; then
        print_error "Domain name required when using --letsencrypt"
        show_usage
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
}

################################################################################
# SSL Setup Functions
################################################################################

setup_selfsigned_certificate() {
    print_step "Creating self-signed SSL certificate"
    
    local CERT_FILE="/etc/ssl/certs/$CERT_NAME.crt"
    local KEY_FILE="/etc/ssl/private/$CERT_NAME.key"
    
    # Create private key directory if it doesn't exist
    mkdir -p /etc/ssl/private
    chmod 700 /etc/ssl/private
    
    # Generate self-signed certificate
    print_info "Generating 2048-bit RSA key and certificate (valid for 365 days)"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=localhost"
    
    # Set proper permissions
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    
    print_info "Certificate created:"
    print_info "  Certificate: $CERT_FILE"
    print_info "  Private Key: $KEY_FILE"
    
    echo -e "${YELLOW}"
    echo "NOTE: Self-signed certificates will show security warnings in browsers."
    echo "This is normal and acceptable for testing/development environments."
    echo -e "${NC}"
}

setup_letsencrypt_certificate() {
    print_step "Setting up Let's Encrypt certificate for $DOMAIN"
    
    # Install certbot
    print_step "Installing certbot"
    apt update
    apt install -y certbot python3-certbot-apache
    
    # Stop Apache temporarily to allow certbot standalone mode
    print_info "Temporarily stopping Apache"
    systemctl stop apache2
    
    # Get certificate using standalone mode
    print_step "Obtaining certificate from Let's Encrypt"
    print_warning "Make sure port 80 is accessible from the internet!"
    print_warning "Make sure $DOMAIN points to this server's IP address!"
    
    if certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN"; then
        print_info "Certificate obtained successfully!"
    else
        print_error "Failed to obtain certificate from Let's Encrypt"
        systemctl start apache2
        exit 1
    fi
    
    # Setup auto-renewal
    print_step "Setting up automatic certificate renewal"
    systemctl enable certbot.timer
    systemctl start certbot.timer
    
    print_info "Certificate location:"
    print_info "  Certificate: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    print_info "  Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
}

configure_apache_ssl() {
    print_step "Configuring Apache for SSL/TLS"
    
    local CONFIG_SOURCE="$APP_DIR/apache/apache-config-ssl-example.conf"
    local CONFIG_DEST="/etc/apache2/sites-available/$SITE_NAME-ssl.conf"
    
    if [ ! -f "$CONFIG_SOURCE" ]; then
        print_error "SSL configuration template not found: $CONFIG_SOURCE"
        exit 1
    fi
    
    # Copy and update configuration
    cp "$CONFIG_SOURCE" "$CONFIG_DEST"
    
    # Update paths in configuration
    sed -i "s|/home/student/MySecretNotes|$APP_DIR|g" "$CONFIG_DEST"
    sed -i "s|mysecretnotesapp|$SITE_NAME|g" "$CONFIG_DEST"
    
    if [ "$USE_LETSENCRYPT" = true ]; then
        # Update ServerName
        sed -i "s|ServerName localhost|ServerName $DOMAIN|g" "$CONFIG_DEST"
        
        # Comment out self-signed cert lines and uncomment Let's Encrypt lines
        sed -i "s|SSLCertificateFile /etc/ssl/certs/|# SSLCertificateFile /etc/ssl/certs/|g" "$CONFIG_DEST"
        sed -i "s|SSLCertificateKeyFile /etc/ssl/private/|# SSLCertificateKeyFile /etc/ssl/private/|g" "$CONFIG_DEST"
        sed -i "s|# SSLCertificateFile /etc/letsencrypt/|SSLCertificateFile /etc/letsencrypt/|g" "$CONFIG_DEST"
        sed -i "s|# SSLCertificateKeyFile /etc/letsencrypt/|SSLCertificateKeyFile /etc/letsencrypt/|g" "$CONFIG_DEST"
        sed -i "s|yourdomain.com|$DOMAIN|g" "$CONFIG_DEST"
    fi
    
    print_info "Configuration created: $CONFIG_DEST"
}

enable_apache_modules() {
    print_step "Enabling required Apache modules"
    a2enmod ssl
    a2enmod rewrite
    a2enmod headers
    print_info "Enabled: ssl, rewrite, headers"
}

enable_ssl_site() {
    print_step "Enabling SSL site configuration"
    
    # Disable old non-SSL site if it exists
    if a2query -s "$SITE_NAME.conf" &>/dev/null; then
        print_info "Disabling old non-SSL configuration"
        a2dissite "$SITE_NAME.conf"
    fi
    
    # Enable SSL site
    a2ensite "$SITE_NAME-ssl.conf"
    print_info "Enabled SSL site: $SITE_NAME-ssl.conf"
}

test_and_restart_apache() {
    print_step "Testing Apache configuration"
    if apache2ctl configtest; then
        echo -e "${GREEN}Configuration test passed!${NC}"
    else
        print_error "Configuration test failed. Please check the error messages above."
        exit 1
    fi
    
    print_step "Restarting Apache"
    systemctl restart apache2
    
    print_step "Checking Apache status"
    systemctl status apache2 --no-pager || true
}

update_flask_app_config() {
    print_step "Checking Flask application configuration"
    
    if grep -q "SESSION_COOKIE_SECURE" "$APP_DIR/app.py" 2>/dev/null; then
        print_info "Flask app already has secure cookie settings"
    else
        print_warning "Consider adding these settings to app.py for HTTPS:"
        echo "  app.config['SESSION_COOKIE_SECURE'] = True"
        echo "  app.config['SESSION_COOKIE_HTTPONLY'] = True"
        echo "  app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'"
    fi
}

print_completion_message() {
    echo ""
    echo "################################################################################"
    echo -e "${GREEN}# SSL/TLS Setup Complete!${NC}"
    echo "################################################################################"
    echo ""
    
    if [ "$USE_LETSENCRYPT" = true ]; then
        echo "Your application is now secured with Let's Encrypt SSL/TLS!"
        echo ""
        echo "Access it at:"
        echo "  - https://$DOMAIN"
        echo ""
        echo "Certificate Auto-Renewal:"
        echo "  - Certbot will automatically renew certificates before expiry"
        echo "  - Check renewal status: sudo certbot renew --dry-run"
        echo "  - View timer status: sudo systemctl status certbot.timer"
    else
        echo "Your application is now secured with a self-signed SSL certificate!"
        echo ""
        echo "Access it at:"
        echo "  - https://localhost"
        echo "  - https://your-server-ip"
        echo ""
        echo -e "${YELLOW}Browser Warning:${NC}"
        echo "  Your browser will show a security warning because the certificate"
        echo "  is self-signed. This is normal for testing/development."
        echo "  You can safely proceed past the warning."
    fi
    
    echo ""
    echo "Troubleshooting:"
    echo "  - View SSL error log: sudo tail -f /var/log/apache2/$SITE_NAME-ssl-error.log"
    echo "  - View SSL access log: sudo tail -f /var/log/apache2/$SITE_NAME-ssl-access.log"
    echo "  - Test SSL configuration: sudo apache2ctl -t -D DUMP_VHOSTS"
    echo "  - Check SSL certificate: openssl s_client -connect localhost:443"
    echo ""
    
    if [ "$USE_LETSENCRYPT" = false ]; then
        echo -e "${BLUE}To use Let's Encrypt in production:${NC}"
        echo "  sudo ./setup-apache-ssl.sh --letsencrypt yourdomain.com $APP_DIR"
        echo ""
    fi
}

################################################################################
# Main Function
################################################################################

main() {
    echo "################################################################################"
    echo "# Apache SSL/TLS Setup for My Secret Notes"
    echo "################################################################################"
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    echo "Configuration:"
    echo "  Application Directory: $APP_DIR"
    echo "  Site Name: $SITE_NAME"
    if [ "$USE_LETSENCRYPT" = true ]; then
        echo "  SSL Type: Let's Encrypt"
        echo "  Domain: $DOMAIN"
    else
        echo "  SSL Type: Self-Signed (for testing)"
    fi
    echo ""
    
    # Perform checks
    check_root
    check_app_directory
    
    # Enable Apache modules
    enable_apache_modules
    
    # Setup SSL certificate
    if [ "$USE_LETSENCRYPT" = true ]; then
        setup_letsencrypt_certificate
    else
        setup_selfsigned_certificate
    fi
    
    # Configure Apache
    configure_apache_ssl
    
    # Enable SSL site
    enable_ssl_site
    
    # Test and restart
    test_and_restart_apache
    
    # Check Flask config
    update_flask_app_config
    
    # Print completion message
    print_completion_message
}

# Run main function with all arguments
main "$@"

