# Setting Up SSL/TLS (HTTPS) for Apache

This guide explains how to secure your My Secret Notes Flask application with SSL/TLS (HTTPS) using Apache.

## Quick Start

### Option 1: Self-Signed Certificate (Testing/Development)

```bash
# Make the script executable
chmod +x setup-apache-ssl.sh

# Run with self-signed certificate
sudo ./setup-apache-ssl.sh --selfsigned

# Or specify a custom directory
sudo ./setup-apache-ssl.sh --selfsigned /var/www/MySecretNotes
```

**Note**: Self-signed certificates will show browser warnings. This is normal for development/testing.

### Option 2: Let's Encrypt Certificate (Production)

**Prerequisites**:
- A registered domain name pointing to your server's IP
- Port 80 and 443 open and accessible from the internet
- Apache already installed (run `setup-apache.sh` first)

```bash
# Run with Let's Encrypt
sudo ./setup-apache-ssl.sh --letsencrypt yourdomain.com

# Or with custom directory
sudo ./setup-apache-ssl.sh --letsencrypt yourdomain.com /var/www/MySecretNotes
```

## What the Script Does

The `setup-apache-ssl.sh` script automatically:

1. ✅ Enables required Apache modules (ssl, rewrite, headers)
2. ✅ Generates/obtains SSL certificates (self-signed or Let's Encrypt)
3. ✅ Configures Apache with SSL/TLS best practices
4. ✅ Sets up HTTP to HTTPS redirect
5. ✅ Adds security headers (HSTS, X-Frame-Options, etc.)
6. ✅ Tests the configuration
7. ✅ Restarts Apache
8. ✅ Sets up auto-renewal for Let's Encrypt certificates

## Manual Setup (Alternative)

If you prefer to set up SSL manually:

### Step 1: Enable SSL Module

```bash
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2enmod headers
```

### Step 2: Generate Self-Signed Certificate

```bash
# Create certificate (valid for 365 days)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/mysecretnotesapp-selfsigned.key \
    -out /etc/ssl/certs/mysecretnotesapp-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Set proper permissions
sudo chmod 600 /etc/ssl/private/mysecretnotesapp-selfsigned.key
sudo chmod 644 /etc/ssl/certs/mysecretnotesapp-selfsigned.crt
```

### Step 3: Or Use Let's Encrypt

```bash
# Install certbot
sudo apt update
sudo apt install certbot python3-certbot-apache

# Stop Apache temporarily
sudo systemctl stop apache2

# Obtain certificate
sudo certbot certonly --standalone -d yourdomain.com

# Enable auto-renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Start Apache again
sudo systemctl start apache2
```

### Step 4: Configure Apache SSL

```bash
# Copy SSL configuration
sudo cp apache/apache-config-ssl-example.conf /etc/apache2/sites-available/mysecretnotesapp-ssl.conf

# Edit the file to update paths if needed
sudo nano /etc/apache2/sites-available/mysecretnotesapp-ssl.conf

# Disable old non-SSL site
sudo a2dissite mysecretnotesapp.conf

# Enable SSL site
sudo a2ensite mysecretnotesapp-ssl.conf

# Test configuration
sudo apache2ctl configtest

# Restart Apache
sudo systemctl restart apache2
```

## Security Features Included

The SSL configuration includes modern security best practices:

### SSL/TLS Configuration
- ✅ **TLS 1.2 and 1.3 only** (disables older insecure protocols)
- ✅ **Strong cipher suites** (HIGH security, no weak ciphers)
- ✅ **Cipher order preference** (server chooses best cipher)

### Security Headers
- ✅ **HSTS** (HTTP Strict Transport Security) - Forces HTTPS for 1 year
- ✅ **X-Frame-Options** - Prevents clickjacking attacks
- ✅ **X-Content-Type-Options** - Prevents MIME sniffing
- ✅ **X-XSS-Protection** - Enables browser XSS filtering

### Redirect Configuration
- ✅ **HTTP → HTTPS redirect** - All HTTP traffic redirected to HTTPS
- ✅ **301 permanent redirect** - SEO-friendly redirect

## Testing Your SSL Setup

### Test in Browser

```bash
# For self-signed
https://localhost

# For Let's Encrypt
https://yourdomain.com
```

### Test with OpenSSL

```bash
# Check certificate
openssl s_client -connect localhost:443

# Check cipher suites
openssl s_client -connect localhost:443 -cipher HIGH
```

### Test with SSL Labs

For production sites with real domains:
- Visit: https://www.ssllabs.com/ssltest/
- Enter your domain name
- Get a detailed security rating

## Certificate Management

### Self-Signed Certificate

**Renewal** (when it expires):
```bash
# Generate new certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/mysecretnotesapp-selfsigned.key \
    -out /etc/ssl/certs/mysecretnotesapp-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Restart Apache
sudo systemctl restart apache2
```

### Let's Encrypt Certificate

**Auto-renewal** (handled automatically):
```bash
# Check renewal status
sudo certbot renew --dry-run

# View renewal timer
sudo systemctl status certbot.timer

# Manual renewal (if needed)
sudo certbot renew
sudo systemctl reload apache2
```

**View certificate info**:
```bash
sudo certbot certificates
```

## Flask Application Updates

For better security with HTTPS, add these to your `app.py`:

```python
# Add after creating the Flask app
app.config['SESSION_COOKIE_SECURE'] = True      # Only send cookies over HTTPS
app.config['SESSION_COOKIE_HTTPONLY'] = True    # Prevent JavaScript access to cookies
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'   # CSRF protection
```

## Troubleshooting

### Check SSL Logs

```bash
# SSL error log
sudo tail -f /var/log/apache2/mysecretnotesapp-ssl-error.log

# SSL access log
sudo tail -f /var/log/apache2/mysecretnotesapp-ssl-access.log
```

### Common Issues

#### 1. Browser Shows "Your connection is not private"

**For self-signed certificates**: This is expected! Click "Advanced" → "Proceed to localhost"

**For Let's Encrypt**: 
- Check domain points to correct IP: `nslookup yourdomain.com`
- Verify certificate: `sudo certbot certificates`

#### 2. Apache Won't Start

```bash
# Check configuration
sudo apache2ctl configtest

# Check what's using port 443
sudo lsof -i :443

# View detailed error
sudo systemctl status apache2
```

#### 3. Let's Encrypt Fails

Common causes:
- Domain doesn't point to server IP
- Port 80 is blocked by firewall
- Another service is using port 80

```bash
# Check firewall
sudo ufw status

# Allow ports
sudo ufw allow 80
sudo ufw allow 443
```

#### 4. Mixed Content Warnings

Update your HTML/CSS/JS to use relative URLs or HTTPS:
```html
<!-- Bad -->
<script src="http://example.com/script.js"></script>

<!-- Good -->
<script src="https://example.com/script.js"></script>
<!-- Or -->
<script src="//example.com/script.js"></script>
```

### Verify Apache Modules

```bash
# Check enabled modules
apache2ctl -M | grep ssl
apache2ctl -M | grep rewrite
apache2ctl -M | grep headers
```

### Check Virtual Host Configuration

```bash
# List all virtual hosts
sudo apache2ctl -t -D DUMP_VHOSTS
```

## Port Configuration

Make sure ports are open:

```bash
# Check listening ports
sudo netstat -tlnp | grep apache

# Should show:
# *:80  (HTTP)
# *:443 (HTTPS)
```

## Production Checklist

Before deploying to production with SSL:

- [ ] Use Let's Encrypt (not self-signed)
- [ ] Domain properly points to server
- [ ] Firewall allows ports 80 and 443
- [ ] HTTPS redirect working (HTTP → HTTPS)
- [ ] Certificate auto-renewal enabled
- [ ] Security headers present (test with browser dev tools)
- [ ] Flask session cookies set to secure
- [ ] Test SSL rating at SSL Labs
- [ ] Update application secrets and keys
- [ ] Enable firewall (ufw or iptables)

## Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Apache SSL/TLS Documentation](https://httpd.apache.org/docs/2.4/ssl/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [SSL Labs Server Test](https://www.ssllabs.com/ssltest/)

## Security Notes

⚠️ **Important**: While SSL/TLS secures the connection, your application still has the following vulnerabilities that need to be addressed:

1. SQL injection vulnerabilities
2. Plaintext password storage
3. No CSRF protection
4. Session security issues

SSL/TLS encrypts the data in transit, but doesn't fix application-level security issues!

