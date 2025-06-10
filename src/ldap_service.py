from flask import Flask, request, session, redirect, url_for, render_template_string
from ldap3 import Server, Connection, ALL
import os

app = Flask(__name__)
app.secret_key = os.urandom(16)
LDAP_SERVER = 'ldap://localhost'
BASE_DN = 'dc=example,dc=com'

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        user = request.form['user']
        pwd = request.form['pass']
        conn = Connection(Server(LDAP_SERVER, get_info=ALL),
                          user=f"uid={user},{BASE_DN}",
                          password=pwd)
        if conn.bind():  
            session['user'] = user
            return redirect(url_for('profile'))
        else:
            return "Login failed", 401
    return '''
        <form method="post">
            User: <input name="user"><br>
            Pass: <input name="pass" type="password"><br>
            <button>Login</button>
        </form>
    '''

@app.route('/profile')
def profile():
    if 'user' not in session:
        return redirect(url_for('login'))
    u = request.args.get('user', session['user'])
    conn = Connection(Server(LDAP_SERVER, get_info=ALL),
                      user=f"cn=admin,{BASE_DN}", password='adminSecret')
    conn.bind()
    conn.search(BASE_DN, f"(uid={u})", attributes=['uid', 'cn', 'mail'])
    entries = conn.entries
    output = ""
    for entry in entries:
        output += f"<p>User: {entry.uid}, Name: {entry.cn}, Email: {entry.mail}</p>"
    return render_template_string("""
        <h2>Profile of {{ user }}</h2>
        {{ data|safe }}
        <a href="{{ url_for('logout') }}">Logout</a>
    """, user=u, data=output)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(port=5000, debug=True)
