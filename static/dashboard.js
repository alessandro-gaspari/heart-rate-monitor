console.log('📊 Dashboard script caricato');

// --- Variabili Globali ---
let chart;
let socket;
let map;
let marker;

// Posizione iniziale
let lastKnownPosition = [45.4642, 9.19];

// Statistiche locali
let localStats = { sum: 0, count: 0, min: Infinity, max: 0 };

// --- STATO SMART FOLLOW ---
let isFollowMode = true; // Se true, il grafico scorre da solo
const VISIBLE_POINTS = 50; // Quanti punti mostrare in modalità follow

// ============================================================
// 1. GESTIONE GRAFICO (Chart.js + Smart Zoom)
// ============================================================

function initChart() {
    const canvas = document.getElementById('heartRateChart');
    if (!canvas) {
        console.error('❌ Canvas #heartRateChart non trovato');
        return;
    }

    // Listener per il ripristino (Doppio Click)
    canvas.addEventListener('dblclick', () => {
        console.log('▶️ Ripristino Follow Mode');
        isFollowMode = true;
        chart.resetZoom();
        const total = chart.data.labels.length;
        if (total > VISIBLE_POINTS) {
            chart.options.scales.x.min = total - VISIBLE_POINTS;
            chart.options.scales.x.max = total - 1;
        }
        chart.update('none');
    });

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
                    grid: { color: 'rgba(255, 215, 0, 0.1)', drawBorder: false },
                    ticks: { color: '#cccccc', maxRotation: 0, autoSkip: true, maxTicksLimit: 8 }
                },
                y: {
                    beginAtZero: false,
                    min: 40,
                    max: 200,
                    grid: { color: 'rgba(255, 215, 0, 0.1)', drawBorder: false },
                    ticks: { color: '#cccccc', stepSize: 20, callback: (val) => val + ' bpm' }
                }
            },
            plugins: {
                legend: { display: false },
                tooltip: {
                    mode: 'index',
                    intersect: false,
                    backgroundColor: 'rgba(26, 26, 26, 0.95)',
                    titleColor: '#FFD700',
                    callbacks: { label: (c) => c.parsed.y + ' BPM' }
                },
                zoom: {
                    pan: {
                        enabled: true,
                        mode: 'x',
                        onPanStart: () => {
                            if (isFollowMode) {
                                console.log('⏸️ Follow Mode in pausa (Pan)');
                                isFollowMode = false;
                            }
                        }
                    },
                    zoom: {
                        wheel: { enabled: true },
                        pinch: { enabled: true },
                        mode: 'x',
                        onZoomStart: () => {
                            if (isFollowMode) {
                                console.log('⏸️ Follow Mode in pausa (Zoom)');
                                isFollowMode = false;
                            }
                        }
                    },
                    limits: {
                        y: { min: 30, max: 240 }
                    }
                }
            }
        }
    });

    console.log('✅ Grafico inizializzato');
}

function addDataToChart(bpm, timestamp) {
    if (!chart) return;

    const date = timestamp ? new Date(timestamp) : new Date();
    const timeLabel = date.toLocaleTimeString('it-IT', {
        hour: '2-digit', minute: '2-digit', second: '2-digit'
    });

    chart.data.labels.push(timeLabel);
    chart.data.datasets[0].data.push(bpm);

    const totalPoints = chart.data.labels.length;

    if (isFollowMode) {
        if (totalPoints > VISIBLE_POINTS) {
            chart.options.scales.x.min = totalPoints - VISIBLE_POINTS;
            chart.options.scales.x.max = totalPoints - 1;
        } else {
            delete chart.options.scales.x.min;
            delete chart.options.scales.x.max;
        }
    }

    chart.update('none');
}

// ============================================================
// 2. STATISTICHE
// ============================================================

function updateLocalStats(bpm) {
    if (!Number.isFinite(bpm) || bpm <= 0) return;
    localStats.count++;
    localStats.sum += bpm;
    if (bpm < localStats.min) localStats.min = bpm;
    if (bpm > localStats.max) localStats.max = bpm;

    const avg = Math.round(localStats.sum / localStats.count);

    const setTxt = (id, val) => { 
        const el = document.getElementById(id); 
        if(el) el.textContent = val; 
    };

    setTxt('avgBpm', avg);
    setTxt('minBpm', localStats.min);
    setTxt('maxBpm', localStats.max);
    setTxt('totalSamples', localStats.count);
}

function loadInitialStats() {
    fetch('/api/stats')
        .then(res => res.json())
        .then(data => {
            if (!data.total_samples) return;
            localStats.count = data.total_samples;
            localStats.min = data.min_bpm;
            localStats.max = data.max_bpm;
            localStats.sum = data.avg_bpm * data.total_samples;
            updateLocalStats(0);

            document.getElementById('avgBpm').textContent = data.avg_bpm;
            document.getElementById('minBpm').textContent = data.min_bpm;
            document.getElementById('maxBpm').textContent = data.max_bpm;
        });
}

// ============================================================
// 3. MAPPA
// ============================================================

function initMap() {
    const el = document.getElementById('map');
    if (!el) return;

    map = L.map('map', { zoomControl: false }).setView(lastKnownPosition, 13);
    L.control.zoom({ position: 'topright' }).addTo(map);
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; OSM', maxZoom: 19
    }).addTo(map);

    const icon = L.divIcon({
        className: 'gps-marker',
        html: '<div class="marker-pulse"></div><div class="marker-dot"></div>',
        iconSize: [60, 60], iconAnchor: [30, 30]
    });
    marker = L.marker(lastKnownPosition, { icon: icon }).addTo(map);

    const btn = L.control({ position: 'bottomright' });
    btn.onAdd = () => {
        const d = L.DomUtil.create('div');
        d.innerHTML = `<button style="background:linear-gradient(135deg, #FFD700, #FFA500);border:none;width:50px;height:50px;border-radius:50%;font-size:24px;cursor:pointer;box-shadow:0 4px 10px rgba(0,0,0,0.5)">📍</button>`;
        d.onclick = (e) => { e.stopPropagation(); map.setView(lastKnownPosition, 16, {animate:true}); };
        return d;
    };
    btn.addTo(map);

    const style = document.createElement('style');
    style.innerHTML = `.gps-marker{width:60px;height:60px}.marker-pulse{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:50px;height:50px;background:rgba(255,215,0,0.3);border-radius:100%;animation:p 2s infinite}.marker-dot{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:16px;height:16px;background:#FFD700;border:3px solid #fff;border-radius:100%;box-shadow:0 0 15px #FFD700}@keyframes p{0%{transform:translate(-50%,-50%) scale(0.5);opacity:1}100%{transform:translate(-50%,-50%) scale(1.5);opacity:0}}`;
    document.head.appendChild(style);
}

function updateMapPosition(lat, lng) {
    if (!map || !marker) return;
    lastKnownPosition = [lat, lng];
    marker.setLatLng(lastKnownPosition);
    const st = document.getElementById('gpsStatus');
    if (st) {
        st.innerHTML = `<i data-lucide="satellite"></i> ${lat.toFixed(5)}, ${lng.toFixed(5)}`;
        st.classList.add('active');
        if(typeof lucide !== 'undefined') lucide.createIcons();
    }
}

// ============================================================
// 4. SOCKET & INIT
// ============================================================

function initSocketIO() {
    socket = io({ transports: ['websocket'], reconnection: true });

    socket.on('connect', () => {
        document.getElementById('connectionDot').classList.add('connected');
        document.getElementById('statusText').textContent = 'Connesso';
    });

    socket.on('disconnect', () => {
        document.getElementById('connectionDot').classList.remove('connected');
        document.getElementById('statusText').textContent = 'Disconnesso';
    });

    socket.on('new_heart_rate', (data) => {
        const bpm = data.heart_rate;
        document.getElementById('currentBpm').textContent = bpm;
        document.getElementById('lastUpdate').textContent = 'Aggiornato ora';

        addDataToChart(bpm, data.timestamp);
        updateLocalStats(bpm);

        if (data.latitude && data.longitude) updateMapPosition(data.latitude, data.longitude);
    });
}

function loadHistoricalData() {
    fetch('/api/recent')
        .then(res => res.json())
        .then(data => {
            if (!Array.isArray(data)) return;
            data.forEach(item => {
                if (item.heart_rate > 0) addDataToChart(item.heart_rate, item.timestamp);
            });

            if (chart) {
                const total = chart.data.labels.length;
                if (total > VISIBLE_POINTS) {
                    chart.options.scales.x.min = total - VISIBLE_POINTS;
                    chart.options.scales.x.max = total - 1;
                }
                chart.update('none');
            }
        });
}

document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        initChart();
        initMap();
        initSocketIO();
        loadInitialStats();
        loadHistoricalData();
        if (typeof lucide !== 'undefined') lucide.createIcons();
    }, 100);
});