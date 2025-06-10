#!/usr/bin/env python3
"""
Vulnerable Web Application - Educational Purpose Only
This application contains several web2 vulnerabilities:
1. SQL Injection in login and search functionality
2. Cross-Site Scripting (XSS) in message display
3. Insecure file upload with no validation
4. Insecure direct object references
5. Command injection in admin panel

WARNING: This is for educational purposes only. Never deploy this in production!
"""

from flask import Flask, request, render_template_string, redirect, url_for, session, send_file
import sqlite3
import os
import subprocess
import hashlib

app = Flask(__name__)
app.secret_key = 'vulnerable_secret_key_123'  # Weak secret key

# Initialize database
def init_db():
    conn = sqlite3.connect('vulnerable_app.db')
    c = conn.cursor()
    
    # Users table
    c.execute('''CREATE TABLE IF NOT EXISTS users
                 (id INTEGER PRIMARY KEY, username TEXT, password TEXT, role TEXT)''')
    
    # Messages table
    c.execute('''CREATE TABLE IF NOT EXISTS messages
                 (id INTEGER PRIMARY KEY, user_id INTEGER, title TEXT, content TEXT, filename TEXT)''')
    
    # Insert default admin user (weak password)
    c.execute("INSERT OR IGNORE INTO users (username, password, role) VALUES ('admin', 'admin123', 'admin')")
    c.execute("INSERT OR IGNORE INTO users (username, password, role) VALUES ('user', 'password', 'user')")
    
    conn.commit()
    conn.close()

# Create uploads directory
os.makedirs('uploads', exist_ok=True)

@app.route('/')
def index():
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Vulnerable Message Board</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
            .nav { background: #333; color: white; padding: 10px; margin-bottom: 20px; }
            .nav a { color: white; text-decoration: none; margin-right: 15px; }
            .message { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
            input, textarea { width: 100%; padding: 8px; margin: 5px 0; }
            button { background: #007cba; color: white; padding: 10px 20px; border: none; cursor: pointer; }
            .error { color: red; margin: 10px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="nav">
                <a href="/">Home</a>
                <a href="/login">Login</a>
                <a href="/messages">Messages</a>
                <a href="/search">Search</a>
                {% if session.get('username') %}
                    <a href="/post">Post Message</a>
                    {% if session.get('role') == 'admin' %}
                        <a href="/admin">Admin Panel</a>
                    {% endif %}
                    <a href="/logout">Logout ({{ session.username }})</a>
                {% endif %}
            </div>
            
            <h1>Welcome to the Vulnerable Message Board</h1>
            <p>This is a demonstration application with intentional security vulnerabilities for educational purposes.</p>
            
            {% if not session.get('username') %}
                <p><a href="/login">Please login to post messages</a></p>
            {% endif %}
            
            <h2>Recent Messages</h2>
            {% for message in messages %}
                <div class="message">
                    <h3>{{ message[2]|safe }}</h3>
                    <p>{{ message[3]|safe }}</p>
                    <small>By User ID: {{ message[1] }}</small>
                    {% if message[4] %}
                        <br><a href="/download/{{ message[4] }}">Download: {{ message[4] }}</a>
                    {% endif %}
                </div>
            {% endfor %}
        </div>
    </body>
    </html>
    ''', messages=get_recent_messages())

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        # VULNERABILITY 1: SQL Injection
        conn = sqlite3.connect('vulnerable_app.db')
        c = conn.cursor()
        # Unsafe SQL query - vulnerable to SQL injection
        query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"
        c.execute(query)
        user = c.fetchone()
        conn.close()
        
        if user:
            session['user_id'] = user[0]
            session['username'] = user[1]
            session['role'] = user[3]
            return redirect(url_for('index'))
        else:
            error = 'Invalid credentials'
    
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head><title>Login</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h2>Login</h2>
        {% if error %}
            <p style="color: red;">{{ error }}</p>
        {% endif %}
        <form method="post">
            <p>Username: <input type="text" name="username" required></p>
            <p>Password: <input type="password" name="password" required></p>
            <button type="submit">Login</button>
        </form>
        <p><a href="/">Back to Home</a></p>
        <p><small>Try: admin/admin123 or user/password<br>
        Or try SQL injection: admin'--</small></p>
    </body>
    </html>
    ''', error=error)

@app.route('/search')
def search():
    query = request.args.get('q', '')
    messages = []
    
    if query:
        # VULNERABILITY 2: SQL Injection in search
        conn = sqlite3.connect('vulnerable_app.db')
        c = conn.cursor()
        # Unsafe search query
        sql = f"SELECT * FROM messages WHERE title LIKE '%{query}%' OR content LIKE '%{query}%'"
        c.execute(sql)
        messages = c.fetchall()
        conn.close()
    
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head><title>Search Messages</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h2>Search Messages</h2>
        <form method="get">
            <input type="text" name="q" value="{{ query }}" placeholder="Search messages...">
            <button type="submit">Search</button>
        </form>
        
        {% if query %}
            <h3>Search Results for: {{ query|safe }}</h3>
            {% for message in messages %}
                <div style="border: 1px solid #ddd; padding: 10px; margin: 10px 0;">
                    <h4>{{ message[2]|safe }}</h4>
                    <p>{{ message[3]|safe }}</p>
                </div>
            {% endfor %}
        {% endif %}
        
        <p><a href="/">Back to Home</a></p>
        <p><small>Try searching for: test<br>
        Or try SQL injection: ' UNION SELECT 1,1,username,password,1 FROM users--</small></p>
    </body>
    </html>
    ''', query=query, messages=messages)

@app.route('/post', methods=['GET', 'POST'])
def post_message():
    if not session.get('username'):
        return redirect(url_for('login'))
    
    if request.method == 'POST':
        title = request.form['title']
        content = request.form['content']
        filename = None
        
        # VULNERABILITY 3: Insecure file upload
        if 'file' in request.files:
            file = request.files['file']
            if file.filename:
                # No validation on file type or content!
                filename = file.filename
                file.save(os.path.join('uploads', filename))
        
        # Store message (no XSS protection)
        conn = sqlite3.connect('vulnerable_app.db')
        c = conn.cursor()
        c.execute("INSERT INTO messages (user_id, title, content, filename) VALUES (?, ?, ?, ?)",
                  (session['user_id'], title, content, filename))
        conn.commit()
        conn.close()
        
        return redirect(url_for('index'))
    
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head><title>Post Message</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h2>Post New Message</h2>
        <form method="post" enctype="multipart/form-data">
            <p>Title: <input type="text" name="title" required></p>
            <p>Content: <textarea name="content" rows="5" required></textarea></p>
            <p>Upload File: <input type="file" name="file"></p>
            <button type="submit">Post Message</button>
        </form>
        <p><a href="/">Back to Home</a></p>
        <p><small>Try posting XSS: &lt;script&gt;alert('XSS')&lt;/script&gt;</small></p>
    </body>
    </html>
    ''')

@app.route('/messages')
def messages():
    conn = sqlite3.connect('vulnerable_app.db')
    c = conn.cursor()
    c.execute("SELECT * FROM messages ORDER BY id DESC")
    all_messages = c.fetchall()
    conn.close()
    
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head><title>All Messages</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h2>All Messages</h2>
        {% for message in messages %}
            <div style="border: 1px solid #ddd; padding: 10px; margin: 10px 0;">
                <h3>{{ message[2]|safe }}</h3>
                <p>{{ message[3]|safe }}</p>
                <small>Message ID: {{ message[0] }}, User ID: {{ message[1] }}</small>
                {% if message[4] %}
                    <br><a href="/download/{{ message[4] }}">{{ message[4] }}</a>
                {% endif %}
            </div>
        {% endfor %}
        <p><a href="/">Back to Home</a></p>
    </body>
    </html>
    ''', messages=all_messages)

@app.route('/download/<filename>')
def download_file(filename):
    # VULNERABILITY 4: Path traversal
    # No validation - allows directory traversal attacks
    try:
        return send_file(os.path.join('uploads', filename))
    except:
        return "File not found", 404

@app.route('/admin')
def admin_panel():
    if not session.get('username') or session.get('role') != 'admin':
        return "Access denied", 403
    
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head><title>Admin Panel</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h2>Admin Panel</h2>
        <h3>System Commands</h3>
        <form method="post" action="/admin/cmd">
            <p>Command: <input type="text" name="cmd" placeholder="ls -la"></p>
            <button type="submit">Execute</button>
        </form>
        
        <h3>User Management</h3>
        <a href="/admin/users">View All Users</a>
        
        <p><a href="/">Back to Home</a></p>
        <p><small>Try commands like: ls, whoami, cat /etc/passwd</small></p>
    </body>
    </html>
    ''')

@app.route('/admin/cmd', methods=['POST'])
def admin_command():
    if not session.get('username') or session.get('role') != 'admin':
        return "Access denied", 403
    
    cmd = request.form['cmd']
    
    # VULNERABILITY 5: Command injection
    try:
        # Extremely dangerous - executes any command!
        result = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as e:
        result = f"Error: {e.output}"
    except Exception as e:
        result = f"Error: {str(e)}"
    
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head><title>Command Result</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h2>Command Result</h2>
        <pre style="background: #f0f0f0; padding: 10px;">{{ result }}</pre>
        <p><a href="/admin">Back to Admin Panel</a></p>
    </body>
    </html>
    ''', result=result)

@app.route('/admin/users')
def admin_users():
    if not session.get('username') or session.get('role') != 'admin':
        return "Access denied", 403
    
    conn = sqlite3.connect('vulnerable_app.db')
    c = conn.cursor()
    c.execute("SELECT * FROM users")
    users = c.fetchall()
    conn.close()
    
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head><title>User Management</title></head>
    <body style="font-family: Arial; margin: 40px;">
        <h2>All Users</h2>
        <table border="1" style="border-collapse: collapse;">
            <tr><th>ID</th><th>Username</th><th>Password</th><th>Role</th></tr>
            {% for user in users %}
                <tr>
                    <td>{{ user[0] }}</td>
                    <td>{{ user[1] }}</td>
                    <td>{{ user[2] }}</td>
                    <td>{{ user[3] }}</td>
                </tr>
            {% endfor %}
        </table>
        <p><a href="/admin">Back to Admin Panel</a></p>
    </body>
    </html>
    ''', users=users)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

def get_recent_messages():
    conn = sqlite3.connect('vulnerable_app.db')
    c = conn.cursor()
    c.execute("SELECT * FROM messages ORDER BY id DESC LIMIT 5")
    messages = c.fetchall()
    conn.close()
    return messages

if __name__ == '__main__':
    init_db()
    print("WARNING: This application contains intentional security vulnerabilities!")
    print("Only use for educational purposes in a safe environment.")
    print("Starting vulnerable web application on http://localhost:5000")
    app.run(debug=True, host='0.0.0.0', port=5000) 
