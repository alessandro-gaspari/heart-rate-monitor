var chart;
var ws;
var maxDataPoints = 50;

// Colori per device type
const deviceColors = {
    'heartRateBand': '#FF4444',  // Rosso
    'armband': '#FF8C00',        // Arancione
    'unknown': '#9B59B6',        // Viola
    'none': '#3498DB'            // Blu default
};

function getDeviceColor(deviceType) {
    return deviceColors[deviceType] || deviceColors['none'];
}

function initWebSocket() {
    // USA LA STESSA PORTA DELLA PAGINA
    var protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    var wsUrl = protocol + '//' + window.location.host;  // NO PORTA
    
    console.log('🔌 Connessione a:', wsUrl);
    
    ws = new WebSocket(wsUrl);
    
    ws.onopen = function() {
        console.log('✅ Connesso');
        ws.send('dashboard');
        document.getElementById('statusText').textContent = 'Connesso';
        document.getElementById('connectionDot').classList.add('connected');
    };
    
    // ... resto uguale
}


function updateCurrentBPM(bpm, timestamp, deviceType, color) {
    var bpmElement = document.getElementById('currentBpm');
    bpmElement.textContent = bpm;
    bpmElement.style.color = color;
    
    var heartIcon = document.getElementById('heartIcon');
    heartIcon.style.animation = 'none';
    setTimeout(function() {
        heartIcon.style.animation = 'heartbeat 1.2s infinite';
    }, 10);
    
    var date = new Date(timestamp);
    var timeString = date.toLocaleTimeString('it-IT');
    
    document.getElementById('lastUpdate').textContent = 
        'Ultimo aggiornamento: ' + timeString + ' | Dispositivo: ' + deviceType;
}

function initChart() {
    var ctx = document.getElementById('heartRateChart');
    chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Heart Rate (BPM)',
                data: [],
                borderColor: '#667eea',
                backgroundColor: 'rgba(102, 126, 234, 0.1)',
                borderWidth: 3,
                tension: 0.4,
                fill: true,
                pointRadius: 4,
                pointHoverRadius: 6,
                pointBackgroundColor: '#667eea',
                pointBorderColor: '#fff',
                pointBorderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: false,
                    suggestedMin: 50,
                    suggestedMax: 150
                }
            },
            plugins: {
                legend: {
                    display: false
                }
            }
        }
    });
}

function addDataToChart(timestamp, value, color) {
    var date = new Date(timestamp);
    var timeLabel = date.toLocaleTimeString('it-IT');
    
    chart.data.labels.push(timeLabel);
    chart.data.datasets[0].data.push(value);
    
    // Aggiorna colore linea con l'ultimo device type
    chart.data.datasets[0].borderColor = color;
    chart.data.datasets[0].pointBackgroundColor = color;
    
    if (chart.data.labels.length > maxDataPoints) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    
    chart.update('none');
}

function loadStatistics() {
    fetch('/api/statistics')
        .then(response => response.json())
        .then(stats => {
            document.getElementById('avgBpm').textContent = stats.avg_hr || '--';
            document.getElementById('minBpm').textContent = stats.min_hr || '--';
            document.getElementById('maxBpm').textContent = stats.max_hr || '--';
            document.getElementById('totalSamples').textContent = stats.total_samples || '--';
        })
        .catch(error => console.error('❌ Errore statistiche:', error));
}

function loadHistory() {
    fetch('/api/history/5')
        .then(response => response.json())
        .then(data => {
            data.reverse().forEach(item => {
                var color = getDeviceColor(item.device_type || 'unknown');
                addDataToChart(item.timestamp, item.heart_rate, color);
            });
        })
        .catch(error => console.error('❌ Errore storico:', error));
}

document.addEventListener('DOMContentLoaded', function() {
    console.log('📊 Inizializzazione dashboard...');
    initChart();
    initWebSocket();
    loadHistory();
    loadStatistics();
    setInterval(loadStatistics, 5000);
});