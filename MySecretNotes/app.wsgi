#!/usr/bin/python3
import sys
import os

# Add the application directory to the Python path
sys.path.insert(0, '/home/student/My-Secret-Notes-Defence-Group23/MySecretNotes')

# Change to the application directory
os.chdir('/home/student/My-Secret-Notes-Defence-Group23/MySecretNotes')

# Import the Flask application
from app import app as application

# For debugging (remove in production)
application.debug = False

