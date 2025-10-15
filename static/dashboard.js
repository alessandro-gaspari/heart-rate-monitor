console.log('📊 Dashboard script caricato');

let chart;
let socket;
let currentBpm = 0;
let map;
let marker;
let userHasMovedMap = false;

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

// Inizializza mappa con bottone centramento moderno
// Inizializza mappa con bottone centramento moderno
function initMap() {
    const mapContainer = document.getElementById('map');
    if (!mapContainer) {
        console.error('❌ Elemento map non trovato');
        return;
    }
    
    map = L.map('map', {
        zoomControl: false // Rimuoviamo controlli default
    }).setView([45.4642, 9.19], 13);
    
    // Aggiungi controllo zoom in posizione custom
    L.control.zoom({
        position: 'topright'
    }).addTo(map);
    
    // Tema dark sportivo
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap contributors © CARTO',
        maxZoom: 19,
        subdomains: 'abcd'
    }).addTo(map);
    
    // Marker pulsante personalizzato
    const markerHtml = `
        <div style="position: relative; width: 30px; height: 30px;">
            <div style="position: absolute; width: 30px; height: 30px; background: rgba(239, 68, 68, 0.3); border-radius: 50%; animation: pulse 2s infinite;"></div>
            <div style="position: absolute; top: 5px; left: 5px; width: 20px; height: 20px; background: #ef4444; border: 3px solid white; border-radius: 50%; box-shadow: 0 0 20px rgba(239,68,68,0.8);"></div>
        </div>
    `;
    
    const customIcon = L.divIcon({
        className: 'custom-marker',
        html: markerHtml,
        iconSize: [30, 30],
        iconAnchor: [15, 15]
    });
    
    marker = L.marker([45.4642, 9.19], { icon: customIcon }).addTo(map);
    
    // Traccia solo DRAG intenzionale (non click o zoom)
    let isDragging = false;
    
    map.on('dragstart', () => {
        isDragging = true;
    });
    
    map.on('dragend', () => {
        if (isDragging) {
            userHasMovedMap = true;
            console.log('🗺️ Utente ha spostato la mappa manualmente');
        }
    });
    
    map.on('zoomstart', (e) => {
        // Segna come "mosso" solo se lo zoom è manuale (non programmatico)
        if (!e.originalEvent) return; // Ignora zoom programmatico
        userHasMovedMap = true;
        console.log('🔍 Utente ha zoomato manualmente');
    });
    
    // Bottone centramento stile iOS
    const centerBtn = L.control({ position: 'bottomright' });
    centerBtn.onAdd = function() {
        const div = L.DomUtil.create('div', 'leaflet-bar leaflet-control');
        div.style.marginBottom = '20px';
        div.style.marginRight = '10px';
        
        div.innerHTML = `
            <button id="centerMapBtn" title="Centra sulla posizione" style="
                background: linear-gradient(135deg, #ef4444, #dc2626);
                color: white;
                border: none;
                width: 50px;
                height: 50px;
                border-radius: 50%;
                font-size: 24px;
                cursor: pointer;
                box-shadow: 0 4px 20px rgba(239, 68, 68, 0.6);
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                display: flex;
                align-items: center;
                justify-content: center;
            " onmouseover="this.style.transform='scale(1.15) rotate(90deg)'; this.style.boxShadow='0 6px 30px rgba(239, 68, 68, 0.8)';" 
               onmouseout="this.style.transform='scale(1) rotate(0deg)'; this.style.boxShadow='0 4px 20px rgba(239, 68, 68, 0.6)';">
                <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
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
            if (marker) {
                map.setView(marker.getLatLng(), 17, { 
                    animate: true, 
                    duration: 1,
                    easeLinearity: 0.25
                });
                userHasMovedMap = false;
                console.log('📍 Mappa ricentrata sulla posizione');
            }
        };
        
        return div;
    };
    centerBtn.addTo(map);
    
    // Aggiungi stile CSS per animazione pulse
    const style = document.createElement('style');
    style.textContent = `
        @keyframes pulse {
            0%, 100% { transform: scale(1); opacity: 1; }
            50% { transform: scale(2.5); opacity: 0; }
        }
    `;
    document.head.appendChild(style);
    
    console.log('✅ Mappa inizializzata');
}

// Aggiorna posizione mappa (centra SOLO se utente non ha mai interagito)
function updateMapPosition(latitude, longitude) {
    if (!map || !marker) return;
    
    const newPos = [latitude, longitude];
    
    // Aggiorna SEMPRE il marker (mostra dove sei)
    marker.setLatLng(newPos);
    
    // Centra la mappa SOLO se l'utente non ha MAI interagito
    if (!userHasMovedMap) {
        map.setView(newPos, 16, { 
            animate: true,
            duration: 0.5 
        });
    }
    
    // Aggiorna status GPS
    const gpsStatus = document.getElementById('gpsStatus');
    if (gpsStatus) {
        gpsStatus.innerHTML = `
            <i data-lucide="satellite"></i>
            <span>GPS: ${latitude.toFixed(5)}, ${longitude.toFixed(5)}</span>
        `;
        gpsStatus.classList.add('active');
        
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    }
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