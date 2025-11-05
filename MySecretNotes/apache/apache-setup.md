# Deploying My Secret Notes with Apache on Ubuntu

This guide will help you deploy the Flask application with Apache web server using mod_wsgi on Ubuntu 20.04.

## Prerequisites

1. **Apache2** installed
2. **Python 3** installed
3. **mod_wsgi** for Python 3
4. **Flask** and other Python dependencies

## Installation Steps for Ubuntu 20.04

### 1. Install Required Software

```bash
sudo apt update
sudo apt install apache2 libapache2-mod-wsgi-py3 python3-pip
```

### 2. Install Python Dependencies

```bash
cd /home/student/MySecretNotes
pip3 install flask
# or if you have a requirements.txt:
# pip3 install -r requirements.txt
```

### 3. Configure Apache

1. Copy the configuration file to Apache's sites-available directory:
```bash
cd /home/student/MySecretNotes
sudo cp apache/apache-config-example.conf /etc/apache2/sites-available/mysecretnotesapp.conf
```

2. Enable the site:
```bash
sudo a2ensite mysecretnotesapp.conf
```

3. Enable mod_wsgi (usually already enabled with libapache2-mod-wsgi-py3):
```bash
sudo a2enmod wsgi
```

4. Disable the default site (optional but recommended):
```bash
sudo a2dissite 000-default.conf
```

### 4. Set Proper Permissions

The Apache user (www-data) needs to read your application files and write to the database:

```bash
# Make www-data the owner of the application directory
sudo chown -R www-data:www-data /home/student/MySecretNotes

# Set directory permissions
sudo chmod 755 /home/student/MySecretNotes

# Set database file permissions (read/write for www-data)
sudo chmod 664 /home/student/MySecretNotes/db.sqlite3

# Make sure the directory is writable (for database updates)
sudo chmod 775 /home/student/MySecretNotes
```

### 5. Test Configuration

```bash
sudo apache2ctl configtest
```

You should see "Syntax OK"

### 6. Restart Apache

```bash
sudo systemctl restart apache2
```

You can also check the status:
```bash
sudo systemctl status apache2
```

### 7. Access Your Application

Open your web browser and navigate to:
- `http://localhost` or
- `http://your-server-ip`

## Troubleshooting

### Check Apache Error Logs

```bash
# Application-specific error log
sudo tail -f /var/log/apache2/mysecretnotesapp-error.log

# General Apache error log
sudo tail -f /var/log/apache2/error.log

# Access log
sudo tail -f /var/log/apache2/mysecretnotesapp-access.log
```

### Common Issues

1. **Permission Denied Errors**: Make sure Apache has read access to your files and write access to db.sqlite3

2. **Module not found**: Ensure Flask is installed in a location accessible to Apache's Python environment

3. **Port 80 already in use**: Either stop other services using port 80, or change the port in the VirtualHost configuration

4. **Database errors**: Ensure the database file has proper permissions and the directory is writable

### Testing Without Apache

You can still test your application directly:
```bash
python3 app.py
```

Then access it at `http://localhost:5000`

## Security Considerations

⚠️ **WARNING**: This application has several SQL injection vulnerabilities and other security issues. Before deploying to production:

1. Use parameterized queries instead of string formatting for SQL
2. Hash passwords (use bcrypt or similar)
3. Add CSRF protection
4. Set secure session configurations
5. Use HTTPS (configure SSL/TLS in Apache)
6. Keep the secret_key persistent (current implementation regenerates on restart)

## Running on Port 80

If you want Apache to run on port 80 (default HTTP port):

1. Make sure no other service is using port 80:
```bash
# Check what's using port 80
sudo lsof -i :80
```

2. Apache needs root privileges to bind to port 80

3. Access your app at `http://localhost` (no port number needed)

