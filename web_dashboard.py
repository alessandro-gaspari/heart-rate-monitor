from flask import Flask, render_template, jsonify
import sqlite3

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/statistics')
def get_statistics():
    conn = sqlite3.connect('heart_rate_data.db')
    conn.row_factory = sqlite3.Row
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
    
    # Statistiche per device type
    cursor.execute('''
        SELECT device_type, COUNT(*) as count
        FROM heart_rate
        GROUP BY device_type
    ''')
    device_stats = cursor.fetchall()
    
    conn.close()
    
    return jsonify({
        'total_samples': stats['total'] or 0,
        'avg_hr': round(stats['avg'], 1) if stats['avg'] else 0,
        'min_hr': stats['min'] or 0,
        'max_hr': stats['max'] or 0,
        'device_types': [{'type': row['device_type'], 'count': row['count']} for row in device_stats]
    })

@app.route('/api/history/<int:minutes>')
def get_history(minutes):
    conn = sqlite3.connect('heart_rate_data.db')
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT timestamp, heart_rate, device_type
        FROM heart_rate
        ORDER BY timestamp DESC
        LIMIT ?
    ''', (minutes * 12,))
    
    data = [{
        'timestamp': row['timestamp'],
        'heart_rate': row['heart_rate'],
        'device_type': row['device_type']
    } for row in cursor.fetchall()]
    
    conn.close()
    return jsonify(data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
