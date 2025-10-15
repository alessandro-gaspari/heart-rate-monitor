console.log('📊 Dashboard script caricato');

let chart;
let socket;
let currentBpm = 0;
let map;
let marker;

// Inizializza il grafico Chart.js
function initChart() {
    const ctx = document.getElementById('heartRateChart');
    if (!ctx) {
        console.error('❌ Canvas heartRateChart non trovato');
        return;
    }

    chart = new Chart(ctx, {
        type: 'line',
        data: { // ✅ AGGIUNTO 'data:'
            labels: [],
            datasets: [{
                label: 'Heart Rate (BPM)',
                data: [], // ✅ AGGIUNTO 'data: []'
                borderColor: '#06b6d4',
                backgroundColor: 'rgba(6, 182, 212, 0.2)',
                borderWidth: 3,
                tension: 0.4,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 7,
                pointBackgroundColor: '#06b6d4',
                pointBorderColor: '#fff',
                pointHoverBackgroundColor: '#06b6d4',
                pointHoverBorderColor: '#fff',
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: { mode: 'index', intersect: false },
            scales: {
                x: { 
                    grid: { color: 'rgba(255,255,255,0.05)' },
                    ticks: { color: '#94a3b8', font: { family: 'Inter', size: 11 } }
                },
                y: {
                    min: 40,
                    max: 180,
                    grid: { color: 'rgba(255,255,255,0.05)' },
                    ticks: {
                        color: '#94a3b8',
                        font: { family: 'Inter', size: 12 },
                        callback: val => val + ' bpm'
                    }
                }
            },
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: 'rgba(15,23,42,0.9)',
                    titleColor: '#06b6d4',
                    bodyColor: '#fff',
                    borderColor: '#06b6d4',
                    borderWidth: 1,
                    displayColors: false,
                    titleFont: { family: 'Inter', size: 13, weight: '600' },
                    bodyFont: { family: 'Orbitron', size: 16, weight: '700' },
                    callbacks: {
                        label: ctx => ctx.parsed.y + ' BPM'
                    }
                }
            }
        }
    });

    console.log('✅ Grafico inizializzato');
}

// Inizializza la mappa Leaflet
function initMap() {
    const mapContainer = document.getElementById('map');
    if (!mapContainer) {
        console.error('❌ Elemento map non trovato');
        return;
    }

    map = L.map('map').setView([45.4642, 9.19], 13);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap contributors © CARTO',
        maxZoom: 19,
        subdomains: 'abcd',
    }).addTo(map);
    
    const markerHtml = `
        <div style="position: relative; width: 26px; height: 26px;">
            <div style="
                position: absolute;
                width: 26px;
                height: 26px;
                background: rgba(6, 182, 212, 0.3);
                border-radius: 50%;
                animation: pulse 2s infinite;
            "></div>
            <div style="
                position: absolute;
                top: 4px;
                left: 4px;
                width: 18px;
                height: 18px;
                background: #06b6d4;
                border: 3px solid white;
                border-radius: 50%;
                box-shadow: 0 0 15px rgba(6,182,212,0.8);
            "></div>
        </div>
    `;

    const customIcon = L.divIcon({
        className: 'custom-marker',
        html: markerHtml,
        iconSize: [26, 26],
        iconAnchor: [13, 13]
    });

    marker = L.marker([45.4642, 9.19], { icon: customIcon }).addTo(map);

    console.log('✅ Mappa inizializzata');
}

// Aggiorna la posizione sulla mappa
function updateMapPosition(lat, lng) {
    if (!map || !marker) return;
    const newPos = [lat, lng];
    marker.setLatLng(newPos);
    map.setView(newPos, 16, { animate: true, duration: 1 });

    const gpsStatus = document.getElementById('gpsStatus');
    if (gpsStatus) {
        gpsStatus.innerHTML = `
            <i data-lucide="satellite"></i>
            <span>GPS: ${lat.toFixed(5)}, ${lng.toFixed(5)}</span>
        `;
        gpsStatus.classList.add('active');
        lucide.createIcons();
    }
    console.log(`📍 Posizione aggiornata a ${lat}, ${lng}`);
}

// Aggiungi un nuovo dato al grafico
function addDataToChart(val) {
    if (!chart) return;
    const now = new Date();
    const label = now.toLocaleTimeString('it-IT', { hour12: false });
    chart.data.labels.push(label);
    chart.data.datasets[0].data.push(val);
    if (chart.data.labels.length > 50) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    chart.update('none');
}

// Richiama statistiche iniziali
function loadStats() {
    fetch('/api/stats')
        .then(res => res.json())
        .then(data => {
            document.getElementById('avgBpm').textContent = data.avg_bpm || '--';
            document.getElementById('minBpm').textContent = data.min_bpm || '--';
            document.getElementById('maxBpm').textContent = data.max_bpm || '--';
            document.getElementById('totalSamples').textContent = data.total_samples || '--';
        })
        .catch(console.error);
}

// Carica dati storici per riempire il grafico
function loadHistoricalData() {
    fetch('/api/recent')
        .then(res => res.json())
        .then(data => {
            data.forEach(item => {
                const ts = new Date(item.timestamp);
                chart.data.labels.push(ts.toLocaleTimeString('it-IT', { hour12: false }));
                chart.data.datasets[0].data.push(item.heart_rate);
            });
            chart.update();
        })
        .catch(console.error);
}

// Inizializza Socket.IO
function initSocketIO() {
    socket = io({
        transports: ['websocket'],
        reconnection: true,
        reconnectionDelay: 1000,
        reconnectionAttempts: 10
    });

    socket.on('connect', () => {
        console.log('✅ Socket.IO connesso');
        document.getElementById('statusText').textContent = 'Connesso';
        document.getElementById('connectionDot').classList.add('connected');
    });

    socket.on('disconnect', () => {
        console.log('⚠️ Socket.IO disconnesso');
        document.getElementById('statusText').textContent = 'Disconnesso';
        document.getElementById('connectionDot').classList.remove('connected');
    });

    socket.on('new_heart_rate', data => {
        console.log('📊 Nuovi dati:', data);
        const bpm = data.heart_rate;
        document.getElementById('currentBpm').textContent = bpm;
        document.getElementById('lastUpdate').textContent = 'Aggiornato ora';
        addDataToChart(bpm);

        if (data.latitude && data.longitude) {
            updateMapPosition(data.latitude, data.longitude);
        }
    });

    socket.on('connect_error', error => {
        console.error('❌ Errore Socket.IO:', error);
    });
}

// Inizializzazione generale
document.addEventListener('DOMContentLoaded', () => {
    initChart();
    initMap();
    initSocketIO();
    loadStats();
    loadHistoricalData();

    const bpmEl = document.getElementById('currentBpm');
    if (bpmEl) {
        bpmEl.style.transition = 'transform 0.2s cubic-bezier(0.4, 0, 0.2, 1)';
    }

    console.log('✅ Dashboard pronta');
});