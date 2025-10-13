from flask import Flask, render_template, jsonify
import sqlite3
from datetime import datetime, timedelta
import os

app = Flask(__name__)

def get_db_connection():
    conn = sqlite3.connect('heart_rate_data.db')
    conn.row_factory = sqlite3.Row
    return conn

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/current')
def get_current_data():
    """Ottieni l'ultimo dato registrato"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('SELECT * FROM heart_rate ORDER BY id DESC LIMIT 1')
    last_hr = cursor.fetchone()
    
    cursor.execute('SELECT AVG(heart_rate) as avg FROM heart_rate WHERE timestamp > datetime("now", "-1 minute")')
    avg_hr = cursor.fetchone()
    
    conn.close()
    
    if last_hr:
        return jsonify({
            'heart_rate': last_hr['heart_rate'],
            'timestamp': last_hr['timestamp'],
            'avg_last_minute': round(avg_hr['avg'], 1) if avg_hr['avg'] else 0
        })
    return jsonify({'heart_rate': 0, 'timestamp': None, 'avg_last_minute': 0})

@app.route('/api/history/<int:minutes>')
def get_history(minutes):
    """Ottieni storico degli ultimi N minuti"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    time_limit = (datetime.now() - timedelta(minutes=minutes)).isoformat()
    
    cursor.execute('''
        SELECT timestamp, heart_rate 
        FROM heart_rate 
        WHERE timestamp > ? 
        ORDER BY timestamp ASC
    ''', (time_limit,))
    
    data = [{'timestamp': row['timestamp'], 'heart_rate': row['heart_rate']} for row in cursor.fetchall()]
    conn.close()
    
    return jsonify(data)

@app.route('/api/statistics')
def get_statistics():
    """Ottieni statistiche generali"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT 
            COUNT(*) as total,
            AVG(heart_rate) as avg,
            MIN(heart_rate) as min,
            MAX(heart_rate) as max
        FROM heart_rate
    ''')
    
    stats = cursor.fetchone()
    
    cursor.execute('SELECT AVG(rr_interval) FROM rr_intervals')
    avg_rr = cursor.fetchone()
    
    conn.close()
    
    return jsonify({
        'total_samples': stats['total'],
        'avg_hr': round(stats['avg'], 1) if stats['avg'] else 0,
        'min_hr': stats['min'] or 0,
        'max_hr': stats['max'] or 0,
        'avg_rr_interval': round(avg_rr[0], 2) if avg_rr[0] else 0
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))
    app.run(host='0.0.0.0', port=port, debug=False)
