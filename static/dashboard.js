var chart;
var socket;
var maxDataPoints = 50;

// Colori per device type
const deviceColors = {
    'heartRateBand': '#FF4444',
    'armband': '#FF8C00',
    'unknown': '#9B59B6',
    'none': '#3498DB'
};

function getDeviceColor(deviceType) {
    return deviceColors[deviceType] || deviceColors['none'];
}

function initSocketIO() {
    console.log('🔌 Connessione Socket.IO...');
    
    socket = io();
    
    socket.on('connect', function() {
        console.log('✅ Connesso');
        socket.emit('dashboard');
        document.getElementById('statusText').textContent = 'Connesso';
        document.getElementById('connectionDot').classList.add('connected');
    });
    
    socket.on('heart_rate_update', function(data) {
        console.log('📨 Dati ricevuti:', data);
        var deviceType = data.device_type || 'unknown';
        var color = getDeviceColor(deviceType);
        updateCurrentBPM(data.heart_rate, data.timestamp, deviceType, color);
        addDataToChart(data.timestamp, data.heart_rate, color);
    });
    
    socket.on('disconnect', function() {
        console.log('⚠️ Disconnesso');
        document.getElementById('statusText').textContent = 'Disconnesso';
        document.getElementById('connectionDot').classList.remove('connected');
    });
    
    socket.on('error', function(error) {
        console.error('❌ Errore Socket.IO:', error);
    });
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
    if (!ctx) {
        console.error('❌ Elemento canvas non trovato');
        return;
    }
    
    chart = new Chart(ctx, {
        type: 'line',
        data: {   // 🔧 aggiunto "data"
            labels: [],
            datasets: [{
                label: 'Heart Rate (BPM)',
                data: [],   // 🔧 aggiunto "data: []"
                borderColor: '#06b6d4',
                backgroundColor: 'rgba(6, 182, 212, 0.1)',
                borderWidth: 3,
                tension: 0.4,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 8,
                pointBackgroundColor: '#06b6d4',
                pointBorderColor: '#fff',
                pointBorderWidth: 2,
                pointHoverBackgroundColor: '#06b6d4',
                pointHoverBorderColor: '#fff',
                pointHoverBorderWidth: 3
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                intersect: false,
                mode: 'index'
            },
            scales: {
                x: {
                    display: true,
                    grid: {
                        color: 'rgba(255, 255, 255, 0.05)',
                        drawBorder: false
                    },
                    ticks: {
                        color: '#94a3b8',
                        font: {
                            family: 'Inter',
                            size: 11
                        }
                    }
                },
                y: {
                    beginAtZero: false,
                    suggestedMin: 50,
                    suggestedMax: 150,
                    grid: {
                        color: 'rgba(255, 255, 255, 0.05)',
                        drawBorder: false
                    },
                    ticks: {
                        color: '#94a3b8',
                        font: {
                            family: 'Inter',
                            size: 12
                        },
                        callback: function(value) {
                            return value + ' bpm';
                        }
                    }
                }
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 23, 42, 0.9)',
                    titleColor: '#06b6d4',
                    bodyColor: '#fff',
                    borderColor: '#06b6d4',
                    borderWidth: 1,
                    padding: 12,
                    displayColors: false,
                    titleFont: {
                        family: 'Inter',
                        size: 13,
                        weight: '600'
                    },
                    bodyFont: {
                        family: 'Orbitron',
                        size: 16,
                        weight: '700'
                    },
                    callbacks: {
                        label: function(context) {
                            return context.parsed.y + ' BPM';
                        }
                    }
                }
            }
        }
    });
    console.log('✅ Grafico inizializzato');
}

function addDataToChart(timestamp, value, color) {
    if (!chart) {
        console.error('❌ Grafico non inizializzato');
        return;
    }
    
    var date = new Date(timestamp);
    var timeLabel = date.toLocaleTimeString('it-IT');
    
    chart.data.labels.push(timeLabel);
    chart.data.datasets[0].data.push(value);
    
    // Aggiorna colore linea
    chart.data.datasets[0].borderColor = color;
    chart.data.datasets[0].pointBackgroundColor = color;
    
    // Mantieni solo gli ultimi N punti
    if (chart.data.labels.length > maxDataPoints) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    
    chart.update('none');
}

function loadStatistics() {
    fetch('/api/statistics')
        .then(function(response) {
            return response.json();
        })
        .then(function(stats) {
            document.getElementById('avgBpm').textContent = stats.avg_hr || '--';
            document.getElementById('minBpm').textContent = stats.min_hr || '--';
            document.getElementById('maxBpm').textContent = stats.max_hr || '--';
            document.getElementById('totalSamples').textContent = stats.total_samples || '--';
        })
        .catch(function(error) {
            console.error('❌ Errore statistiche:', error);
        });
}

function loadHistory() {
    fetch('/api/history/5')
        .then(function(response) {
            return response.json();
        })
        .then(function(data) {
            data.reverse().forEach(function(item) {
                var color = getDeviceColor(item.device_type || 'unknown');
                addDataToChart(item.timestamp, item.heart_rate, color);
            });
        })
        .catch(function(error) {
            console.error('❌ Errore storico:', error);
        });
}

// Inizializzazione al caricamento pagina
document.addEventListener('DOMContentLoaded', function() {
    console.log('📊 Inizializzazione dashboard...');
    initChart();
    initSocketIO();
    loadHistory();
    loadStatistics();
    setInterval(loadStatistics, 5000);
});