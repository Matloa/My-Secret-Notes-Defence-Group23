# Apache Configuration Files

This folder contains all Apache-related configuration files and documentation for deploying My Secret Notes with Apache web server.

## Files

### Setup Scripts
- **`setup-apache.sh`** - Automated Apache setup script (HTTP)
- **`setup-apache-ssl.sh`** - Automated Apache SSL/TLS setup script (HTTPS)

### Configuration Templates
- **`apache-config-example.conf`** - Basic Apache configuration (HTTP only)
- **`apache-config-ssl-example.conf`** - SSL/TLS Apache configuration (HTTPS)

### Documentation
- **`apache-setup.md`** - Complete guide for setting up Apache with HTTP
- **`apache-ssl-setup.md`** - Complete guide for setting up Apache with SSL/TLS (HTTPS)

## Usage

### Automated Setup

Run the setup scripts from **anywhere** - they automatically detect the project directory:

```bash
# From the apache folder
cd apache
sudo ./setup-apache.sh
sudo ./setup-apache-ssl.sh --selfsigned

# Or from the project root
cd ..
sudo ./apache/setup-apache.sh
sudo ./apache/setup-apache-ssl.sh --selfsigned


The scripts automatically detect the project directory and find the configuration files.