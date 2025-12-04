console.log('📊 Dashboard script caricato');

let chart;
let socket;
let map;
let marker;

// Posizione di default (Milano)
let lastKnownPosition = [45.4642, 9.19];

// Statistiche locali incrementali
let localStats = {
    sum: 0,
    count: 0,
    min: Number.POSITIVE_INFINITY,
    max: 0
};

// ======================= GRAFICO (Chart.js) =======================

function initChart() {
    const canvas = document.getElementById('heartRateChart');
    if (!canvas) {
        console.error('❌ Canvas #heartRateChart non trovato');
        return;
    }

    const ctx = canvas.getContext('2d');
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
                borderWidth: 3,
                tension: 0.4,
                fill: true,
                pointRadius: 0,
                pointHoverRadius: 8,
                pointBackgroundColor: '#FFD700',
                pointBorderColor: '#000',
                pointBorderWidth: 3,
                pointHoverBackgroundColor: '#FFD700',
                pointHoverBorderColor: '#FFF',
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
                duration: 300,
                easing: 'easeOutQuad'
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
                        autoSkipPadding: 20
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
                        font: { family: 'Inter', size: 12 },
                        callback: v => v + ' bpm',
                        stepSize: 20
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
                    borderWidth: 2,
                    padding: 14,
                    displayColors: false,
                    titleFont: { family: 'Inter', size: 13, weight: '600' },
                    bodyFont: { family: 'Orbitron', size: 18, weight: '700' },
                    callbacks: {
                        label: ctx => ctx.parsed.y + ' BPM'
                    }
                }
            }
        }
    });

    console.log('✅ Grafico inizializzato');
}

function addDataToChart(bpm, timestamp) {
    if (!chart) return;

    const t = timestamp ? new Date(timestamp) : new Date();
    const timeLabel = t.toLocaleTimeString('it-IT', {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });

    chart.data.labels.push(timeLabel);
    chart.data.datasets[0].data.push(bpm);

    const MAX_POINTS = 50;
    if (chart.data.labels.length > MAX_POINTS) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }

    chart.update('none');
}

// ======================= STATISTICHE LOCALI =======================

function updateLocalStats(bpm) {
    if (!Number.isFinite(bpm) || bpm <= 0) return;

    localStats.count += 1;
    localStats.sum += bpm;
    if (bpm < localStats.min) localStats.min = bpm;
    if (bpm > localStats.max) localStats.max = bpm;

    const avg = Math.round(localStats.sum / localStats.count);

    const avgEl = document.getElementById('avgBpm');
    const minEl = document.getElementById('minBpm');
    const maxEl = document.getElementById('maxBpm');
    const totEl = document.getElementById('totalSamples');

    if (avgEl) avgEl.textContent = avg;
    if (minEl) minEl.textContent = localStats.min;
    if (maxEl) maxEl.textContent = localStats.max;
    if (totEl) totEl.textContent = localStats.count;
}

// Usa le stats dal backend come stato iniziale
function loadInitialStats() {
    fetch('/api/stats')
        .then(r => r.json())
        .then(data => {
            const total = data.total_samples || 0;
            if (total <= 0) return;

            localStats.count = total;
            localStats.min = data.min_bpm || 0;
            localStats.max = data.max_bpm || 0;
            localStats.sum = (data.avg_bpm || 0) * total;

            const avgEl = document.getElementById('avgBpm');
            const minEl = document.getElementById('minBpm');
            const maxEl = document.getElementById('maxBpm');
            const totEl = document.getElementById('totalSamples');

            if (avgEl) avgEl.textContent = data.avg_bpm || 0;
            if (minEl) minEl.textContent = data.min_bpm || 0;
            if (maxEl) maxEl.textContent = data.max_bpm || 0;
            if (totEl) totEl.textContent = total;
        })
        .catch(err => console.error('❌ Errore stats iniziali:', err));
}

// ======================= STORICO INIZIALE =======================

function loadHistoricalData() {
    fetch('/api/recent')
        .then(r => r.json())
        .then(items => {
            if (!chart || !Array.isArray(items)) return;
            items.forEach(item => {
                if (!item.heart_rate) return;
                addDataToChart(item.heart_rate, item.timestamp);
                updateLocalStats(item.heart_rate);
            });
            chart.update();
        })
        .catch(err => console.error('❌ Errore dati storici:', err));
}

// ======================= MAPPA (Leaflet) =======================

function initMap() {
    const mapEl = document.getElementById('map');
    if (!mapEl) {
        console.error('❌ Elemento #map non trovato');
        return;
    }

    map = L.map('map', { zoomControl: false }).setView(lastKnownPosition, 13);

    L.control.zoom({ position: 'topright' }).addTo(map);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap',
        maxZoom: 19
    }).addTo(map);

    const pulseIcon = L.divIcon({
        className: 'gps-marker',
        html: '<div class="marker-pulse"></div><div class="marker-dot"></div>',
        iconSize: [60, 60],
        iconAnchor: [30, 30]
    });

    marker = L.marker(lastKnownPosition, { icon: pulseIcon }).addTo(map);

    // Pulsante per centrare
    const centerBtn = L.control({ position: 'bottomright' });
    centerBtn.onAdd = function () {
        const div = L.DomUtil.create('div', '');
        div.style.cssText = 'margin-bottom:20px;margin-right:20px;background:transparent;border:none;box-shadow:none;';
        div.innerHTML = `
            <button title="Centra su GPS" style="
                background: linear-gradient(135deg, #FFD700, #FFA500);
                color: #000; border: none; width: 70px; height: 70px;
                border-radius: 50%; cursor: pointer;
                box-shadow: 0 6px 25px rgba(255, 215, 0, 0.7);
                display: flex; align-items: center; justify-content: center;
                transition: all 0.3s ease; font-weight: bold; font-size: 36px;">
                📍
            </button>
        `;
        const btn = div.querySelector('button');
        btn.onmouseover = () => btn.style.transform = 'scale(1.1)';
        btn.onmouseout = () => btn.style.transform = 'scale(1)';
        div.onclick = e => {
            e.stopPropagation();
            map.setView(lastKnownPosition, 16, { animate: true, duration: 1 });
        };
        return div;
    };
    centerBtn.addTo(map);

    // Stili marker GPS
    const style = document.createElement('style');
    style.textContent = `
        .gps-marker { position: relative; width: 60px; height: 60px; background: transparent !important; border: none !important; }
        .marker-pulse {
            position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
            width: 50px; height: 50px; background: rgba(255, 215, 0, 0.4);
            border-radius: 100%; animation: pulse 2s infinite;
        }
        .marker-dot {
            position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
            width: 20px; height: 20px; background: #FFD700; border: 4px solid white;
            border-radius: 100%; box-shadow: 0 0 20px rgba(255, 215, 0, 1); z-index: 1000;
        }
        @keyframes pulse {
            0%, 100% { transform: translate(-50%, -50%) scale(1); opacity: 1; }
            50% { transform: translate(-50%, -50%) scale(2); opacity: 0; }
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
            <span>GPS: ${lat.toFixed(5)}, ${lng.toFixed(5)}</span>
        `;
        gpsStatus.classList.add('active');
        if (typeof lucide !== 'undefined') lucide.createIcons();
    }
}

// ======================= SOCKET.IO =======================

function initSocketIO() {
    socket = io({
        transports: ['websocket'],
        reconnection: true,
        reconnectionDelay: 1000,
        reconnectionAttempts: 10
    });

    socket.on('connect', () => {
        console.log('✅ Socket.IO connesso');
        const dot = document.getElementById('connectionDot');
        const text = document.getElementById('statusText');
        if (dot) dot.classList.add('connected');
        if (text) text.textContent = 'Connesso';
    });

    socket.on('disconnect', () => {
        console.log('⚠️ Socket.IO disconnesso');
        const dot = document.getElementById('connectionDot');
        const text = document.getElementById('statusText');
        if (dot) dot.classList.remove('connected');
        if (text) text.textContent = 'Disconnesso';
    });

    socket.on('new_heart_rate', data => {
        const bpm = data.heart_rate;
        if (!bpm) return;

        const bpmEl = document.getElementById('currentBpm');
        const updateEl = document.getElementById('lastUpdate');
        if (bpmEl) bpmEl.textContent = bpm;
        if (updateEl) updateEl.textContent = 'Aggiornato ora';

        addDataToChart(bpm, data.timestamp);
        updateLocalStats(bpm);

        if (data.latitude && data.longitude) {
            updateMapPosition(data.latitude, data.longitude);
        }
    });

    socket.on('connect_error', err => {
        console.error('❌ Errore Socket.IO:', err);
    });
}

// ======================= BOOTSTRAP PAGINA =======================

document.addEventListener('DOMContentLoaded', () => {
    console.log('🚀 Inizializzazione dashboard Coospo...');

    setTimeout(() => {
        initChart();
        initMap();
        initSocketIO();
        loadInitialStats();
        loadHistoricalData();

        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }

        console.log('✔ Dashboard pronta');
    }, 100);
});