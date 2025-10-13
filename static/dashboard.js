var chart;
var ws;
var maxDataPoints = 50;

function initWebSocket() {
    var wsUrl = 'ws://172.20.10.3:8765/dashboard';
    console.log('Connessione a:', wsUrl);
    
    ws = new WebSocket(wsUrl);
    
    ws.onopen = function() {
        console.log('Connesso al server');
        ws.send('dashboard');
        document.getElementById('statusText').textContent = 'Connesso e in ascolto';
        document.getElementById('connectionDot').classList.add('connected');
    };
    
    ws.onmessage = function(event) {
        try {
            var data = JSON.parse(event.data);
            console.log('Dati ricevuti:', data);
            updateCurrentBPM(data.heart_rate, data.timestamp);
            addDataToChart(data.timestamp, data.heart_rate);
        } catch (e) {
            console.error('Errore parsing dati:', e);
        }
    };
    
    ws.onerror = function(error) {
        console.error('Errore WebSocket:', error);
        document.getElementById('statusText').textContent = 'Errore connessione';
        document.getElementById('connectionDot').classList.remove('connected');
    };
    
    ws.onclose = function() {
        console.log('Disconnesso dal server');
        document.getElementById('statusText').textContent = 'Disconnesso - Riconnessione...';
        document.getElementById('connectionDot').classList.remove('connected');
        setTimeout(initWebSocket, 3000);
    };
}

function updateCurrentBPM(bpm, timestamp) {
    var bpmElement = document.getElementById('currentBpm');
    bpmElement.textContent = bpm;
    
    var heartIcon = document.getElementById('heartIcon');
    heartIcon.style.animation = 'none';
    setTimeout(function() {
        heartIcon.style.animation = 'heartbeat 1.2s infinite';
    }, 10);
    
    var date = new Date(timestamp);
    var hours = String(date.getHours()).padStart(2, '0');
    var minutes = String(date.getMinutes()).padStart(2, '0');
    var seconds = String(date.getSeconds()).padStart(2, '0');
    var timeString = hours + ':' + minutes + ':' + seconds;
    
    document.getElementById('lastUpdate').textContent = 'Ultimo aggiornamento: ' + timeString;
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
            animation: {
                duration: 750,
                easing: 'easeInOutQuart'
            },
            interaction: {
                intersect: false,
                mode: 'index'
            },
            scales: {
                y: {
                    beginAtZero: false,
                    suggestedMin: 50,
                    suggestedMax: 150,
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    },
                    ticks: {
                        font: {
                            size: 12,
                            weight: '600'
                        }
                    }
                },
                x: {
                    grid: {
                        display: false
                    },
                    ticks: {
                        maxRotation: 0,
                        autoSkip: true,
                        maxTicksLimit: 10,
                        font: {
                            size: 11
                        }
                    }
                }
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(0, 0, 0, 0.8)',
                    padding: 12,
                    titleFont: {
                        size: 14
                    },
                    bodyFont: {
                        size: 16,
                        weight: 'bold'
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
}

function addDataToChart(timestamp, value) {
    var date = new Date(timestamp);
    var hours = String(date.getHours()).padStart(2, '0');
    var minutes = String(date.getMinutes()).padStart(2, '0');
    var seconds = String(date.getSeconds()).padStart(2, '0');
    var timeLabel = hours + ':' + minutes + ':' + seconds;
    
    chart.data.labels.push(timeLabel);
    chart.data.datasets[0].data.push(value);
    
    if (chart.data.labels.length > maxDataPoints) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    
    chart.update('none');
}

function resetChart() {
    chart.data.labels = [];
    chart.data.datasets[0].data = [];
    chart.update();
    console.log('Grafico resettato');
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
            console.error('Errore caricamento statistiche:', error);
        });
}

function loadHistory() {
    fetch('/api/history/5')
        .then(function(response) {
            return response.json();
        })
        .then(function(data) {
            data.forEach(function(item) {
                addDataToChart(item.timestamp, item.heart_rate);
            });
            console.log('Storico caricato:', data.length, 'campioni');
        })
        .catch(function(error) {
            console.error('Errore caricamento storico:', error);
        });
}

document.addEventListener('DOMContentLoaded', function() {
    console.log('Dashboard inizializzata');
    initChart();
    initWebSocket();
    loadHistory();
    loadStatistics();
    
    setInterval(loadStatistics, 5001);
});