import base64
import json, sqlite3, click, functools, os, hashlib, time, random, sys, re, bcrypt, pyotp, qrcode, io
from flask import Flask, current_app, g, session, redirect, render_template, url_for, request
from flask_wtf import CSRFProtect
from markupsafe import escape

from flask_limiter import Limiter
from flask_limiter.util import get_remote_address


### DATABASE FUNCTIONS ###

def connect_db():
    return sqlite3.connect(app.database)

def init_db():
    """Initializes the database with our great SQL schema"""
    db = connect_db()
    c = db.cursor()

    c.executescript("""
                    DROP TABLE IF EXISTS users;
                    DROP TABLE IF EXISTS notes;

                    CREATE TABLE users
                    (
                        id       INTEGER PRIMARY KEY AUTOINCREMENT,
                        username TEXT NOT NULL,
                        password BLOB NOT NULL,
                        otpSecret TEXT
                    );
                    CREATE TABLE notes
                    (
                        id          INTEGER PRIMARY KEY AUTOINCREMENT,
                        assocUser   INTEGER  NOT NULL,
                        dateWritten DATETIME NOT NULL,
                        note        TEXT     NOT NULL,
                        publicID    INTEGER  NOT NULL
                    );
                    """)

    # TODO: change to safer passwords (but for testing reason leaving it)
    c.execute("INSERT INTO users(username, password) VALUES (?, ?)",
              ("admin", hash_password("password")))
    c.execute("INSERT INTO users(username, password) VALUES (?, ?)",
              ("bernardo", hash_password("omgMPC")))

    c.execute("INSERT INTO notes(assocUser, dateWritten, note, publicID) VALUES (?, ?, ?, ?)",
              (2, "1993-09-23 10:10:10", "hello my friend", 1234567890))
    c.execute("INSERT INTO notes(assocUser, dateWritten, note, publicID) VALUES (?, ?, ?, ?)",
              (2, "1993-09-23 12:10:10", "i want lunch pls", 1234567891))

    db.commit()
    db.close()


### SECURITY FUNCTIONS ###

def validate_password(password):
    if len(password) < 13:
        return "Password must be at least 13 characters"
    if not re.search(r"[A-Z]", password):
        return "Password must include at least one uppercase letter"
    if not re.search(r"[a-z]", password):
        return "Password must include at least one lowercase letter"
    if not re.search(r"[0-9]", password):
        return "Password must include at least one number"
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        return "Password must include at least one special character"
    return None

def hash_password(password):
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(rounds=12))

def verify_password(hashed, password):
    return bcrypt.checkpw(password.encode('utf-8'), hashed)

def generate_otp_secret():
    return pyotp.random_base32()

def verify_otp_secret(otp, token):
    totp = pyotp.TOTP(otp)
    return totp.verify(token)


### APPLICATION SETUP ###
app = Flask(__name__)
app.database = "db.sqlite3"
app.secret_key = os.urandom(32)
csrf = CSRFProtect(app)
app.config['SESSION_COOKIE_SECURE'] = True
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'

# Setup rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["500 per day", "100 per hour"],
    storage_uri="memory://"
)

### ADMINISTRATOR'S PANEL ###
def login_required(view):
    @functools.wraps(view)
    def wrapped_view(**kwargs):
        if not session.get('logged_in'):
            return redirect(url_for('login'))
        return view(**kwargs)
    return wrapped_view

@app.route("/")
def index():
    if not session.get('logged_in'):
        return render_template('index.html')
    else:
        return redirect(url_for('notes'))


@app.route("/notes/", methods=('GET', 'POST'))
@login_required
@limiter.limit("30 per minute")
def notes():
    importerror = ""
    MAX_NOTE_LENGTH = 500
    if request.method == 'POST':
        submit_button = request.form.get('submit_button') # Use .get() to avoid KeyError

        if submit_button == 'add note':
            note_input = request.form.get('noteinput', '').strip()
            if not note_input:
                # empty input
                importerror = "Note cannot be empty."
            elif len(note_input) > MAX_NOTE_LENGTH:
                # overly long input
                importerror = f"Note is too long. Max length is {MAX_NOTE_LENGTH} characters."
            else:
                note_data = note_input 
                try:
                    db = connect_db()
                    c = db.cursor()
                    c.execute("""INSERT INTO notes(id,assocUser,dateWritten,note,publicID) VALUES(null,?,?,?,?)""", (
                        session['userid'], time.strftime('%Y-%m-%d %H:%M:%S'), note_data, random.randrange(1000000000, 9999999999)))
                    db.commit()
                except Exception as e:
                    # potential db error
                    importerror = "An error occurred while saving the note."
                finally:
                    if 'db' in locals():
                        db.close()

        elif submit_button == 'import note':
            noteid_input = request.form.get('noteid', '').strip()
            
            # checking if the input is a 10-digit number 
            if not re.fullmatch(r'^\d{10}$', noteid_input):
                importerror = "Invalid Note ID format. It must be a 10-digit number."
            else:
                noteid = noteid_input
                try:
                    db = connect_db()
                    c = db.cursor()
                    c.execute("SELECT * FROM notes WHERE publicID = ?", (noteid,))
                    result = c.fetchall()
                    
                    if len(result) > 0:
                        row = result[0]
                        imported_note_content = row[3]
                        if len(imported_note_content) > MAX_NOTE_LENGTH:
                            importerror = f"Imported note is too long. Max length is {MAX_NOTE_LENGTH} characters."
                        else:
                            c.execute("""INSERT INTO notes(id,assocUser,dateWritten,note,publicID) VALUES(null, ?, ?, ?, ?)""", (
                                session['userid'], row[2], row[3], row[4]))
                        
                            importerror = "Note imported successfully!"
                    else:
                        importerror = "No such note with that ID!"
                    
                    db.commit()
                except Exception as e:
                    importerror = "An error occurred during note import."
                finally:
                    if 'db' in locals():
                        db.close()

    
    notes = []
    try:
        db = connect_db()
        c = db.cursor()
        c.execute("SELECT * FROM notes WHERE assocUser = ?", (session['userid'],))
        notes = c.fetchall()
    except Exception as e:
        importerror = "Could not retrieve notes due to a server error."
    finally:
        if 'db' in locals():
            db.close()
    return render_template('notes.html', notes=notes, importerror=importerror)


@app.route("/login/", methods=('GET', 'POST'))
@limiter.limit("5 per minute")
def login():
    error = ""
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        otp = request.form['otp']
        db = connect_db()
        c = db.cursor()
        c.execute("SELECT * FROM users WHERE username = ?", (username,))
        result = c.fetchall()
        db.close()

        if len(result) > 0 and verify_password(result[0][2], password):
            otp_secret = result[0][3]
            if not otp_secret:
                error = "2FA not configured for this account."
            elif not verify_otp_secret(otp_secret, otp):
                error = "Invalid 2FA code."
            else:
                session.clear()
                session['logged_in'] = True
                session['userid'] = result[0][0]
                session['username'] = result[0][1]
                return redirect(url_for('index'))
        else:
            error = "Wrong username or password!"
    return render_template('login.html', error=error)


@app.route("/register/", methods=('GET', 'POST'))
@limiter.limit("3 per minute")
def register():
    errored = False
    usererror = ""
    passworderror = ""
    qr_data = None

    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        db = connect_db()
        c = db.cursor()

        errormsg = validate_password(password)
        if errormsg:
            errored = True
            passworderror = errormsg

        c.execute("SELECT * FROM users WHERE username = ?", (username,))
        if len(c.fetchall()) > 0:
            errored = True
            usererror = "Please choose another username."

        if not errored:
            otp_secret = pyotp.random_base32()
            otp_uri = pyotp.totp.TOTP(otp_secret).provisioning_uri(name=username, issuer_name="SecureNotesApp")
            buf = io.BytesIO()
            qrcode.make(otp_uri).save(buf, format='PNG')
            qr_data = base64.b64encode(buf.getvalue()).decode('utf-8')

            session['pending_username'] = username
            session['pending_password'] = hash_password(password)
            session['pending_otp_secret'] = otp_secret

            db.close()

            return render_template('register.html', show_qr=True, qr_data=qr_data, usererror=usererror, passworderror=passworderror)

        db.close()

    return render_template('register.html', show_qr=False, usererror=usererror, passworderror=passworderror)

@app.route("/verify_2fa/", methods=('POST',))
def verify_2fa():
    code = request.form.get('otp_code')
    otp_secret = session.get('pending_otp_secret')
    username = session.get('pending_username')
    hashed_password = session.get('pending_password')

    if not (otp_secret and username and hashed_password):
        return redirect(url_for('register'))

    totp = pyotp.TOTP(otp_secret)
    if totp.verify(code):
        db = connect_db()
        c = db.cursor()
        c.execute("INSERT INTO users(id, username, password, otpSecret) VALUES (null, ?, ?, ?)",
                  (username, hashed_password, otp_secret))
        db.commit()
        db.close()

        session.clear()
        return redirect(url_for('login'))
    else:
        return render_template('register.html', show_qr=True, qr_data=None, otp_error="Invalid 2FA code.")

@app.route("/logout/")
@login_required
def logout():
    """Logout: clears the session"""
    session.clear()
    return redirect(url_for('index'))

if __name__ == "__main__":
    # create database if it doesn't exist yet
    if not os.path.exists(app.database):
        init_db()
    runport = 5000
    if len(sys.argv) == 2:
        runport = sys.argv[1]
    try:
        app.run(host='0.0.0.0', port=runport)  # runs on machine ip address to make it visible on network
    except:
        print("Something went wrong. the usage of the server is either")
        print("'python3 app.py' (to start on port 5000)")
        print("or")
        print("'sudo python3 app.py 80' (to run on any other port)")