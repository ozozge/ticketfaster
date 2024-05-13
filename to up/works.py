# find ~ -type d -name Ticketfaster
# remember to dl mysql and update python extension
# cd /home/coder/project/Ticketfaster
# in terminal: python -m pip install flask

from flask import Flask, render_template, request, redirect, url_for, flash
import mysql.connector
from mysql.connector import Error
import datetime

app = Flask(__name__)
app.secret_key = 'temporary_secret_key'

host = 'localhost'
user = 'root'
password = ''
database = 'ticketfaster'


def get_db_connection():
    connection = None
    try:
        connection = mysql.connector.connect(
            host=host,
            user=user,
            password=password,
            database=database
        )
        print("Connection successful!")
    except Error as error:
        print(f"Failed to connect to MySQL: {error}")
    return connection


@app.route('/')
def index():
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        cursor.execute("SELECT DISTINCT state FROM venue ORDER BY state")
        states = [row[0] for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        return render_template('index.html', states=states)
    else:
        return "Failed to connect to the database"


@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        first_name = request.form['first_name']
        last_name = request.form['last_name']
        username = request.form['username']
        address = request.form['address']
        city = request.form['city']
        state = request.form['state']
        zip_code = request.form['zip_code']
        phone = request.form['phone']
        email = request.form['email']

        # Connect to the database
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            insert_stmt = (
                "INSERT INTO customer (firstname, lastname, username, address, city, state, zip, phone, email, lastmodified) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"
            )
            data = (first_name, last_name, username, address, city,
                    state, zip_code, phone, email, datetime.datetime.now())

            cursor.execute(insert_stmt, data)
            conn.commit()
            cursor.close()
            conn.close()
            return redirect(url_for('signin'))
        else:
            return 'Failed to connect to the database'
    else:
        return render_template('register.html')


@app.route('/signin', methods=['GET', 'POST'])
def signin():
    if request.method == 'POST':
        username = request.form['username']
        email = request.form['email']

        conn = get_db_connection()
        if conn:
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                "SELECT * FROM customer WHERE username = %s AND email = %s", (username, email))
            user = cursor.fetchone()
            cursor.close()
            conn.close()
            if user:
                return redirect(url_for('home', username=username, state=user['state']))
            else:
                # User not found, handle the error or message
                return 'Invalid credentials! Please try again.'
        else:
            return 'Failed to connect to the database'
    else:
        return render_template('signin.html')

# Defining the home route that filters events based on the user's state from customer db:


@app.route('/home')
def home():
    username = request.args.get('username')
    if not username:
        # Redirect to sign-in page if username is not provided
        return redirect(url_for('signin'))

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT state FROM customer WHERE username = %s", (username,))
        user_info = cursor.fetchone()
        cursor.close()
        conn.close()

        if user_info:
            user_state = user_info['state']
            return render_template('home.html', username=username, user_state=user_state)
        else:
            return 'User not found. Please sign in again.'
    else:
        return 'Failed to connect to the database'


@app.route('/search', methods=['GET'])
def search():
    query = request.args.get('query', '')
    state = request.args.get('state', '')
    event_type = request.args.get('event_type', '')

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor(dictionary=True)
        sql_query = """
        SELECT e.ID, e.name as event, e.eventdates, v.name as venue, a.name as artist
        FROM events e
        INNER JOIN venue v ON e.venueid = v.id
        INNER JOIN artist a ON e.artistid = a.id
        WHERE (%s = '' OR e.name LIKE %s)
          AND (%s = '' OR v.state = %s)
          AND (%s = '' OR e.type = %s)
        ORDER BY e.eventdates ASC;
        """
        cursor.execute(
            sql_query, (query, f"%{query}%", state, state, event_type, event_type))
        events = cursor.fetchall()
        cursor.close()
        conn.close()
        return render_template('search_results.html', events=events)
    else:
        return "Failed to connect to the database"


@app.route('/filter_events')
def filter_events():
    event_type = request.args.get('event_type')
    state = request.args.get('state')
    username = request.args.get('username')
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor(dictionary=True)
        query = """
            SELECT e.ID, e.name as event , e.eventdates, v.name as venue, a.name as artist
            FROM events e
            INNER JOIN venue v ON e.venueid = v.id
            INNER JOIN artist a ON e.artistid = a.id
            WHERE e.type = %s AND v.state = %s
            ORDER BY e.eventdates
        """
        cursor.execute(query, (event_type, state))
        events = cursor.fetchall()
        cursor.close()
        conn.close()
        return render_template('events.html', events=events, username=username, user_state=state)
    else:
        return 'Database connection failed'


@app.route('/tickets/<int:event_id>')
def event_tickets(event_id):
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor(dictionary=True)
        # Fetch event details
        cursor.execute("""
            SELECT DISTINCT e.name as Event, v.name as Venue, e.eventdates as EventDate
            FROM events e
            INNER JOIN venue v ON e.venueid = v.id
            WHERE e.id = %s""", (event_id,))
        event_details = cursor.fetchone()

        # Fetch available tickets
        cursor.execute("""
            SELECT  t.ID ,t.eventid ,t.zone, t.rown , t.seat, t.price
            FROM tickets t
            WHERE t.availability = 0 AND t.eventid = %s""", (event_id,))
        tickets = cursor.fetchall()

        cursor.close()
        conn.close()
        return render_template('tickets.html', event_details=event_details, tickets=tickets)
    else:
        return "Failed to connect to the database"


@app.route('/process_payment', methods=['POST'])
def process_payment():
    selected_ticket_id = request.form['selected_ticket']
    # Placeholder for payment processing logic
    return "Processing payment for ticket ID: " + str(selected_ticket_id)


@app.route('/account', methods=['GET', 'POST'])
def account():
    # Retrieve the username from query parameter or session
    username = request.args.get('username')
    conn = get_db_connection()
    if request.method == 'POST':
        if 'delete' in request.form:
            # Handle account deletion
            cursor = conn.cursor()
            cursor.execute(
                "DELETE FROM customer WHERE username = %s", (username,))
            conn.commit()
            cursor.close()
            conn.close()
            # Redirect to sign-in page after deletion
            return redirect(url_for('signin'))
        else:
            # Handle account update
            address = request.form['address']
            city = request.form['city']
            state = request.form['state']
            zip_code = request.form['zip']
            phone = request.form['phone']
            cursor = conn.cursor()
            update_stmt = """UPDATE customer SET address = %s, city = %s, state = %s, zip = %s, phone = %s WHERE username = %s"""
            cursor.execute(update_stmt, (address, city,
                           state, zip_code, phone, username))
            conn.commit()
            cursor.close()
            flash('Account details updated successfully!', 'success')
            cursor.close()
            # Redirect to home page after update
            return redirect(url_for('home', username=username))

    # Fetch user details whether it's a GET request or after POST handling
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT firstname, lastname, address, city, state, zip, phone, email FROM customer WHERE username = %s", (username,))
    user_details = cursor.fetchone()
    cursor.close()
    conn.close()

    if not user_details:
        return 'User not found', 404

    return render_template('account.html', user_details=user_details, username=username)


if __name__ == '__main__':
    app.run(debug=True)

# http://127.0.0.1:5000/
