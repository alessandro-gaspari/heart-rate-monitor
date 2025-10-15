console.log('📊 Dashboard script caricato');

let chart;
let socket;
let currentBpm = 0;
let map;
let marker;
let lastKnownPosition = [45.4642, 9.19];
let userHasMovedMap = false;
let userHasLockeMap = false;

// Inizializza grafico ultra-moderno
function initChart() {
    const ctx = document.getElementById('heartRateChart');
    if (!ctx) {
        console.error('❌ Canvas non trovato');
        return;
    }

    // Gradiente rosso-arancione per area sotto la linea
    const gradient = ctx.getContext('2d').createLinearGradient(0, 0, 0, 400);
    gradient.addColorStop(0, 'rgba(239, 68, 68, 0.4)');
    gradient.addColorStop(0.5, 'rgba(249, 115, 22, 0.2)');
    gradient.addColorStop(1, 'rgba(249, 115, 22, 0)');

    chart = new Chart(ctx, {
        type: 'line',
        data: { // ✅ corretto
            labels: [],
            datasets: [{
                label: 'Heart Rate',
                data: [], // ✅ corretto
                borderColor: '#ef4444',
                backgroundColor: gradient,
                borderWidth: 3,
                tension: 0.4,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 8,
                pointBackgroundColor: '#ef4444',
                pointBorderColor: '#fff',
                pointBorderWidth: 3,
                pointHoverBackgroundColor: '#ef4444',
                pointHoverBorderColor: '#fff',
                pointHoverBorderWidth: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                intersect: false,
                mode: 'index'
            },
            animation: {
                duration: 750,
                easing: 'easeInOutQuart'
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
                        },
                        maxRotation: 0,
                        autoSkipPadding: 20
                    }
                },
                y: {
                    beginAtZero: false,
                    min: 40,
                    max: 200,
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
                        callback: val => val + ' bpm',
                        stepSize: 20
                    }
                }
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 23, 42, 0.95)',
                    titleColor: '#ef4444',
                    bodyColor: '#fff',
                    borderColor: '#ef4444',
                    borderWidth: 2,
                    padding: 14,
                    displayColors: false,
                    titleFont: {
                        family: 'Inter',
                        size: 13,
                        weight: '600'
                    },
                    bodyFont: {
                        family: 'Orbitron',
                        size: 18,
                        weight: '700'
                    },
                    callbacks: {
                        label: ctx => ctx.parsed.y + ' BPM'
                    }
                }
            }
        }
    });

    console.log('✅ Grafico inizializzato');
}


function updateMapPosition(lat, lng) {
    if (!map || !marker) return;
    
    lastKnownPosition = [lat, lng];
    
    // AGGIORNA SOLO IL MARKER - MAI LA VISTA
    marker.setLatLng(lastKnownPosition);
    
    // Aggiorna GPS status
    const gpsStatus = document.getElementById('gpsStatus');
    if (gpsStatus) {
        gpsStatus.innerHTML = `
            <i data-lucide="satellite"></i>
            <span>GPS: ${lat.toFixed(5)}, ${lng.toFixed(5)}</span>
        `;
        gpsStatus.classList.add('active');
        if (typeof lucide !== 'undefined') lucide.createIcons();
    }
}

function initMap() {
    map = L.map('map', { zoomControl: false }).setView([45.4642, 9.19], 13);
    
    L.control.zoom({ position: 'topright' }).addTo(map);
    
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap',
        maxZoom: 19
    }).addTo(map);

    // MARKER CON ICON CORRETTO (anchor al centro perfetto)
    const pulseIcon = L.divIcon({
        className: 'gps-marker',
        html: `
            <div class="marker-pulse"></div>
            <div class="marker-dot"></div>
        `,
        iconSize: [20, 20],
        iconAnchor: [10, 10]  // CENTRO ESATTO del marker
    });
    
    marker = L.marker(lastKnownPosition, { icon: pulseIcon }).addTo(map);

    // Bottone centramento
    const centerBtn = L.control({ position: 'bottomright' });
    centerBtn.onAdd = function() {
        const div = L.DomUtil.create('div', 'leaflet-bar');
        div.style.marginBottom = '20px';
        div.style.marginRight = '10px';
        
        div.innerHTML = `
            <button title="Centra su GPS" style="
                background: linear-gradient(135deg, #ef4444, #dc2626);
                color: white;
                border: none;
                width: 52px;
                height: 52px;
                border-radius: 50%;
                cursor: pointer;
                box-shadow: 0 4px 20px rgba(239, 68, 68, 0.7);
                display: flex;
                align-items: center;
                justify-content: center;
                transition: transform 0.2s ease;
            " onmouseover="this.style.transform='scale(1.1)'" 
               onmouseout="this.style.transform='scale(1)'">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <circle cx="12" cy="12" r="10"></circle>
                    <circle cx="12" cy="12" r="3"></circle>
                    <line x1="12" y1="2" x2="12" y2="6"></line>
                    <line x1="12" y1="18" x2="12" y2="22"></line>
                    <line x1="2" y1="12" x2="6" y2="12"></line>
                    <line x1="18" y1="12" x2="22" y2="12"></line>
                </svg>
            </button>
        `;
        
        div.onclick = function(e) {
            e.stopPropagation();
            map.setView(lastKnownPosition, 16, { animate: true, duration: 1 });
        };
        
        return div;
    };
    centerBtn.addTo(map);

    // CSS per marker GPS
    const style = document.createElement('style');
    style.textContent = `
        .gps-marker {
            position: relative;
            width: 20px;
            height: 20px;
        }
        
        .marker-pulse {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 40px;
            height: 40px;
            background: rgba(239, 68, 68, 0.3);
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        
        .marker-dot {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 16px;
            height: 16px;
            background: #ef4444;
            border: 3px solid white;
            border-radius: 50%;
            box-shadow: 0 0 20px rgba(239, 68, 68, 0.8);
            z-index: 1000;
        }
        
        @keyframes pulse {
            0%, 100% { 
                transform: translate(-50%, -50%) scale(1); 
                opacity: 1; 
            }
            50% { 
                transform: translate(-50%, -50%) scale(2); 
                opacity: 0; 
            }
        }
    `;
    document.head.appendChild(style);
    
    console.log('✅ Mappa inizializzata');
}



// Aggiungi dato al grafico
function addDataToChart(value) {
    if (!chart) return;
    const now = new Date();
    const timeLabel = now.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    chart.data.labels.push(timeLabel);
    chart.data.datasets[0].data.push(value);
    if (chart.data.labels.length > 50) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    chart.update('none');
}

// Carica statistiche
function loadStats() {
    fetch('/api/stats')
        .then(res => res.json())
        .then(data => {
            document.getElementById('avgBpm').textContent = data.avg_bpm || '0';
            document.getElementById('minBpm').textContent = data.min_bpm || '0';
            document.getElementById('maxBpm').textContent = data.max_bpm || '0';
            document.getElementById('totalSamples').textContent = data.total_samples || '0';
        })
        .catch(err => console.error('❌ Errore stats:', err));
}

// Carica dati storici
function loadHistoricalData() {
    fetch('/api/recent')
        .then(res => res.json())
        .then(data => {
            data.forEach(item => {
                const timestamp = new Date(item.timestamp);
                const timeLabel = timestamp.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
                chart.data.labels.push(timeLabel);
                chart.data.datasets[0].data.push(item.heart_rate);
            });
            chart.update();
        })
        .catch(err => console.error('❌ Errore dati storici:', err));
}

// Inizializza Socket.IO
function initSocketIO() {
    socket = io({
        transports: ['websocket'],
        reconnection: true,
        reconnectionDelay: 1000,
        reconnectionAttempts: 10
    });

    socket.on('connect', function() {
        console.log('✅ Socket.IO connesso');
        document.getElementById('connectionDot').classList.add('connected');
        document.getElementById('statusText').textContent = 'Connesso';
    });

    socket.on('disconnect', function() {
        console.log('⚠️ Socket.IO disconnesso');
        document.getElementById('connectionDot').classList.remove('connected');
        document.getElementById('statusText').textContent = 'Disconnesso';
    });

    socket.on('new_heart_rate', function(data) {
        const bpm = data.heart_rate;
        document.getElementById('currentBpm').textContent = bpm;
        document.getElementById('lastUpdate').textContent = 'Aggiornato ora';
        addDataToChart(bpm);
        if (data.latitude && data.longitude) {
            updateMapPosition(data.latitude, data.longitude);
        }
        if (Math.random() < 0.1) loadStats();
    });

    socket.on('connect_error', function(error) {
        console.error('❌ Errore Socket.IO:', error);
    });
}

// Inizializzazione
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Inizializzazione dashboard...');
    initChart();
    initMap();
    initSocketIO();
    loadStats();
    loadHistoricalData();
    setInterval(loadStats, 30000);
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
    console.log('✅ Dashboard pronta');
});