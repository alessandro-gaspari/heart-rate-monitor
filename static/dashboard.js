console.log('📊 Dashboard script caricato');

// --- Variabili Globali ---
let chart;
let socket;
let map;
let marker;

// Posizione iniziale di default (Milano Duomo)
let lastKnownPosition = [45.4642, 9.19];

// Oggetto per il calcolo incrementale delle statistiche
let localStats = {
    sum: 0,
    count: 0,
    min: Infinity,
    max: 0
};

// ============================================================
// 1. GESTIONE GRAFICO (Chart.js + Zoom Plugin)
// ============================================================

function initChart() {
    const canvas = document.getElementById('heartRateChart');
    if (!canvas) {
        console.error('❌ Canvas #heartRateChart non trovato');
        return;
    }

    const ctx = canvas.getContext('2d');

    // Gradiente per l'area sotto la linea
    const gradient = ctx.createLinearGradient(0, 0, 0, 400);
    gradient.addColorStop(0, 'rgba(255, 215, 0, 0.4)');
    gradient.addColorStop(0.5, 'rgba(255, 165, 0, 0.2)');
    gradient.addColorStop(1, 'rgba(255, 165, 0, 0)');

    chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Heart Rate',
                data: [],
                borderColor: '#FFD700',
                backgroundColor: gradient,
                borderWidth: 2,
                tension: 0.4,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 6,
                pointBackgroundColor: '#FFD700',
                pointBorderColor: '#000'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: false,
            interaction: {
                intersect: false,
                mode: 'index'
            },
            scales: {
                x: {
                    display: true,
                    grid: {
                        color: 'rgba(255, 215, 0, 0.1)',
                        drawBorder: false
                    },
                    ticks: {
                        color: '#cccccc',
                        font: { family: 'Inter', size: 11 },
                        maxRotation: 0,
                        autoSkip: true,
                        maxTicksLimit: 8
                    }
                },
                y: {
                    beginAtZero: false,
                    min: 40,
                    max: 200,
                    grid: {
                        color: 'rgba(255, 215, 0, 0.1)',
                        drawBorder: false
                    },
                    ticks: {
                        color: '#cccccc',
                        stepSize: 20,
                        callback: (val) => val + ' bpm'
                    }
                }
            },
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: 'rgba(26, 26, 26, 0.95)',
                    titleColor: '#FFD700',
                    bodyColor: '#fff',
                    borderColor: '#FFD700',
                    borderWidth: 1,
                    displayColors: false,
                    callbacks: {
                        label: (context) => context.parsed.y + ' BPM'
                    }
                },
                zoom: {
                    pan: {
                        enabled: true,
                        mode: 'x'
                    },
                    zoom: {
                        wheel: { enabled: true },
                        pinch: { enabled: true },
                        mode: 'x'
                    },
                    limits: {
                        y: { min: 30, max: 250 }
                    }
                }
            }
        }
    });

    console.log('✅ Grafico inizializzato con Zoom attivo');
}

function addDataToChart(bpm, timestamp) {
    if (!chart) return;

    const date = timestamp ? new Date(timestamp) : new Date();
    const timeLabel = date.toLocaleTimeString('it-IT', {
        hour: '2-digit', minute: '2-digit', second: '2-digit'
    });

    chart.data.labels.push(timeLabel);
    chart.data.datasets[0].data.push(bpm);

    chart.update('none');
}

// ============================================================
// 2. GESTIONE STATISTICHE (Locali e Veloci)
// ============================================================

function updateLocalStats(bpm) {
    if (!Number.isFinite(bpm) || bpm <= 0) return;

    localStats.count++;
    localStats.sum += bpm;

    if (bpm < localStats.min) localStats.min = bpm;
    if (bpm > localStats.max) localStats.max = bpm;

    const avg = Math.round(localStats.sum / localStats.count);

    const elAvg = document.getElementById('avgBpm');
    const elMin = document.getElementById('minBpm');
    const elMax = document.getElementById('maxBpm');
    const elTot = document.getElementById('totalSamples');

    if (elAvg) elAvg.textContent = avg;
    if (elMin) elMin.textContent = localStats.min;
    if (elMax) elMax.textContent = localStats.max;
    if (elTot) elTot.textContent = localStats.count;
}

function loadInitialStats() {
    fetch('/api/stats')
        .then(res => res.json())
        .then(data => {
            if (!data.total_samples || data.total_samples === 0) return;

            localStats.count = data.total_samples;
            localStats.min = data.min_bpm;
            localStats.max = data.max_bpm;
            localStats.sum = data.avg_bpm * data.total_samples;

            updateLocalStats(0);

            document.getElementById('avgBpm').textContent = data.avg_bpm;
            document.getElementById('minBpm').textContent = data.min_bpm;
            document.getElementById('maxBpm').textContent = data.max_bpm;
        })
        .catch(err => console.error('Statistiche non disponibili:', err));
}

// ============================================================
// 3. GESTIONE MAPPA (Leaflet)
// ============================================================

function initMap() {
    const mapElement = document.getElementById('map');
    if (!mapElement) {
        console.error('❌ Elemento #map non trovato');
        return;
    }

    map = L.map('map', { zoomControl: false }).setView(lastKnownPosition, 13);

    L.control.zoom({ position: 'topright' }).addTo(map);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; OpenStreetMap, &copy; CartoDB',
        maxZoom: 19
    }).addTo(map);

    const pulseIcon = L.divIcon({
        className: 'gps-marker',
        html: '<div class="marker-pulse"></div><div class="marker-dot"></div>',
        iconSize: [60, 60],
        iconAnchor: [30, 30]
    });

    marker = L.marker(lastKnownPosition, { icon: pulseIcon }).addTo(map);

    const centerBtn = L.control({ position: 'bottomright' });
    centerBtn.onAdd = function () {
        const div = L.DomUtil.create('div', 'leaflet-bar leaflet-control');
        div.innerHTML = `
            <button title="Centra" style="
                background: linear-gradient(135deg, #FFD700, #FFA500);
                border: none; width: 50px; height: 50px; border-radius: 50%;
                cursor: pointer; font-size: 24px; box-shadow: 0 4px 15px rgba(0,0,0,0.5);
                display:flex; align-items:center; justify-content:center;">
                📍
            </button>`;
        div.onclick = (e) => {
            e.stopPropagation();
            map.setView(lastKnownPosition, 16, { animate: true });
        };
        return div;
    };
    centerBtn.addTo(map);

    const style = document.createElement('style');
    style.textContent = `
        .gps-marker { position: relative; width: 60px; height: 60px; background: transparent !important; border: none !important; }
        .marker-pulse {
            position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
            width: 50px; height: 50px; background: rgba(255, 215, 0, 0.3);
            border-radius: 100%; animation: gpsPulse 2s infinite;
        }
        .marker-dot {
            position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
            width: 16px; height: 16px; background: #FFD700; border: 3px solid white;
            border-radius: 100%; box-shadow: 0 0 15px #FFD700; z-index: 100;
        }
        @keyframes gpsPulse {
            0% { transform: translate(-50%, -50%) scale(0.5); opacity: 1; }
            100% { transform: translate(-50%, -50%) scale(1.5); opacity: 0; }
        }
    `;
    document.head.appendChild(style);

    console.log('✅ Mappa inizializzata');
}

function updateMapPosition(lat, lng) {
    if (!map || !marker) return;

    lastKnownPosition = [lat, lng];
    marker.setLatLng(lastKnownPosition);

    const gpsStatus = document.getElementById('gpsStatus');
    if (gpsStatus) {
        gpsStatus.innerHTML = `
            <i data-lucide="satellite"></i>
            <span>${lat.toFixed(5)}, ${lng.toFixed(5)}</span>
        `;
        gpsStatus.classList.add('active');
        if (typeof lucide !== 'undefined') lucide.createIcons();
    }
}

// ============================================================
// 4. CONNESSIONE SOCKET.IO E DATI
// ============================================================

function initSocketIO() {
    socket = io({
        transports: ['websocket'],
        reconnection: true
    });

    socket.on('connect', () => {
        console.log('✅ Socket Connesso');
        document.getElementById('connectionDot').classList.add('connected');
        document.getElementById('statusText').textContent = 'Connesso';
    });

    socket.on('disconnect', () => {
        console.log('⚠️ Socket Disconnesso');
        document.getElementById('connectionDot').classList.remove('connected');
        document.getElementById('statusText').textContent = 'Disconnesso';
    });

    socket.on('new_heart_rate', (data) => {
        const bpm = data.heart_rate;

        document.getElementById('currentBpm').textContent = bpm;
        document.getElementById('lastUpdate').textContent = 'Aggiornato ora';

        addDataToChart(bpm, data.timestamp);

        updateLocalStats(bpm);

        if (data.latitude && data.longitude) {
            updateMapPosition(data.latitude, data.longitude);
        }
    });
}

function loadHistoricalData() {
    fetch('/api/recent')
        .then(res => res.json())
        .then(data => {
            if (!Array.isArray(data)) return;

            data.forEach(item => {
                if (item.heart_rate > 0) {
                    addDataToChart(item.heart_rate, item.timestamp);
                }
            });

            if (chart) chart.resetZoom();
        })
        .catch(err => console.error('Errore storico:', err));
}

// ============================================================
// 5. INIZIALIZZAZIONE
// ============================================================

document.addEventListener('DOMContentLoaded', () => {
    console.log('🚀 Avvio Dashboard...');

    setTimeout(() => {
        initChart();
        initMap();
        initSocketIO();
        loadInitialStats();
        loadHistoricalData();

        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    }, 100);
});