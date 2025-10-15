let chart, socket, currentBpm = 0, map, marker, userHasMovedMap = false, lastUpdateTimer = null;

// Inizializza grafico
function initChart() {
    const ctx = document.getElementById('heartRateChart');
    if (!ctx) return;
    chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Heart Rate (BPM)',
                data: [],
                borderColor: '#06b6d4',
                backgroundColor: 'rgba(6,182,212,0.1)',
                borderWidth: 3,
                tension: 0.4,
                fill: true
            }]
        },
        options: {
            responsive: true,
            scales: {
                x: { display: false },
                y: { beginAtZero: false, suggestedMin: 50, suggestedMax: 150 }
            },
            plugins: { legend: { display: false } }
        }
    });
}

// Inizializza mappa GPS e UX
function initMap() {
    map = L.map('map').setView([45.4642, 9.19], 13);
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap contributors © CARTO',
        maxZoom: 19,
        subdomains: 'abcd'
    }).addTo(map);

    const customIcon = L.divIcon({
        html: '<div style="width:20px;height:20px;background:#06b6d4;border-radius:50%;box-shadow:0 0 10px #06b6d4;"></div>',
        className: '',
        iconSize: [20, 20],
        iconAnchor: [10, 10]
    });

    marker = L.marker([45.4642, 9.19], { icon: customIcon }).addTo(map);

    // L'utente ha spostato o zoomato la mappa? Non recentrare più
    map.on('movestart zoomstart', () => userHasMovedMap = true);

    // Tasto centra mappa manuale
    const centerControl = L.control({ position: 'topright' });
    centerControl.onAdd = function() {
        const div = L.DomUtil.create('div', 'map-center-btn');
        div.innerHTML = `
            <button title="Centra"
                style="background:#06b6d4;color:white;border:none;padding:0.7em 1em;
                border-radius:50%;font-size:20px;cursor:pointer;box-shadow:0 2px 12px #06b6d4aa;">
                ⌖
            </button>`;
        div.onclick = () => {
            if (marker) {
                map.setView(marker.getLatLng(), 16, { animate: true });
                userHasMovedMap = false;
            }
        };
        return div;
    };
    centerControl.addTo(map);
}

// Aggiorna marker ma centra SOLO se l’utente non si è mosso mai (o ha premuto “centra”)
function updateMapPosition(lat, lng) {
    if (!map || !marker) return;
    const newPos = [lat, lng];
    marker.setLatLng(newPos);
    if (!userHasMovedMap) {
        map.setView(newPos, 16, { animate: true });
    }

    // Aggiorna status GPS visivo
    const gpsStatus = document.getElementById('gpsStatus');
    if (gpsStatus) {
        gpsStatus.innerHTML = `<i data-lucide="satellite"></i> <span>GPS: ${lat.toFixed(5)}, ${lng.toFixed(5)}</span>`;
        gpsStatus.classList.add('active');
        if (typeof lucide !== "undefined") lucide.createIcons();
    }
}

// Aggiungi punto al grafico + gestione max labels
function addDataToChart(val) {
    if (!chart) return;
    const now = new Date().toLocaleTimeString();
    chart.data.labels.push(now);
    chart.data.datasets[0].data.push(val);
    if (chart.data.labels.length > 50) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    chart.update();
}

// Aggiorna indicatori di connessione UI
function updateConnectionStatus() {
    const dot = document.getElementById('connectionDot');
    const txt = document.getElementById('statusText');
    if (!dot || !txt) return;

    if (socket && socket.connected) {
        dot.classList.add('connected');
        txt.textContent = "Connesso";
    } else {
        dot.classList.remove('connected');
        txt.textContent = "Disconnesso";
    }
}

// Socket.IO gestito in modo robusto!
function initSocketIO() {
    socket = io({
        transports: ['websocket'],
        reconnection: true,
        reconnectionDelay: 1000,
        reconnectionAttempts: 99
    });

    socket.on('connect', updateConnectionStatus);
    socket.on('disconnect', updateConnectionStatus);
    socket.on('connect_error', updateConnectionStatus);

    socket.on('new_heart_rate', data => {
        if (lastUpdateTimer) clearTimeout(lastUpdateTimer);
        lastUpdateTimer = setTimeout(() => updateConnectionStatus(), 15000);

        currentBpm = Number(data.heart_rate) > 0 ? data.heart_rate : '--';
        const bpmEl = document.getElementById('currentBpm');
        const lastUpdateEl = document.getElementById('lastUpdate');

        if (bpmEl) bpmEl.textContent = currentBpm;
        if (lastUpdateEl)
            lastUpdateEl.textContent = currentBpm === '--'
                ? 'In attesa di dati...'
                : 'Aggiornato ora';

        if (Number(data.heart_rate) > 0) addDataToChart(data.heart_rate);

        if (Number(data.latitude) && Number(data.longitude)) {
            updateMapPosition(data.latitude, data.longitude);
        }
    });
}

// Placeholder funzioni future
function loadStats() {}
function loadHistoricalData() {}

// Inizializzazione
document.addEventListener('DOMContentLoaded', function() {
    initChart();
    initMap();
    initSocketIO();
    loadStats();
    loadHistoricalData();
    if (window.lucide) lucide.createIcons();
});