console.log('📊 Dashboard script caricato');

let chart;
let socket;
let currentBpm = 0;
let map;
let marker;
let lastKnownPosition = [45.4642, 9.19];

// Inizializza grafico
function initChart() {
    const ctx = document.getElementById('heartRateChart');
    if (!ctx) {
        console.error('❌ Canvas non trovato');
        return;
    }

    // Gradiente giallo-arancione
    const gradient = ctx.getContext('2d').createLinearGradient(0, 0, 0, 400);
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
                duration: 750,
                easing: 'easeInOutQuart'
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
                        callback: val => val + ' bpm',
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

function initMap() {
    const mapElement = document.getElementById('map');
    if (!mapElement) {
        console.error('❌ Elemento #map non trovato nel DOM');
        return;
    }

    map = L.map('map', { zoomControl: false }).setView([45.4642, 9.19], 13);
    
    L.control.zoom({ position: 'topright' }).addTo(map);
    
    // OPZIONE 1: Sfondo grigio chiaro con strade nere (Positron)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
        attribution: '© OpenStreetMap',
        maxZoom: 19,
        className: 'map-tiles-yellow'
    }).addTo(map);

    // OPZIONE 2: Sfondo grigio scuro con strade bianche (Dark Matter No Labels)
    // L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png', {
    //     attribution: '© OpenStreetMap',
    //     maxZoom: 19
    // }).addTo(map);

    const pulseIcon = L.divIcon({
        className: 'gps-marker',
        html: '<div class="marker-pulse"></div><div class="marker-dot"></div>',
        iconSize: [60, 60],
        iconAnchor: [30, 30]
    });
    
    marker = L.marker(lastKnownPosition, { icon: pulseIcon }).addTo(map);

    const centerBtn = L.control({ position: 'bottomright' });
    centerBtn.onAdd = function() {
        const div = L.DomUtil.create('div', 'leaflet-bar');
        div.style.cssText = 'margin-bottom: 20px; margin-right: 10px;';
        div.innerHTML = `
            <button title="Centra su GPS" style="
                background: linear-gradient(135deg, #FFD700, #FFA500);
                color: #000; border: none; width: 70px; height: 70px;
                border-radius: 50%; cursor: pointer;
                box-shadow: 0 6px 25px rgba(255, 215, 0, 0.7);
                display: flex; align-items: center; justify-content: center;
                transition: transform 0.3s ease; font-weight: bold; font-size: 36px;">
                📍
            </button>
        `;
        div.onclick = (e) => {
            e.stopPropagation();
            map.setView(lastKnownPosition, 16, { animate: true, duration: 1 });
        };

        const btn = div.querySelector('button');
        btn.onmouseover = () => btn.style.transform = 'scale(1.1)';
        btn.onmouseout = () => btn.style.transform = 'scale(1)';
        
        div.onclick = (e) => {
            e.stopPropagation();
            map.setView(lastKnownPosition, 16, { animate: true, duration: 1 });
        };
        
        return div;
    };
    centerBtn.addTo(map);

    const style = document.createElement('style');
    style.textContent = `
        .gps-marker { 
            position: relative; 
            width: 60px; 
            height: 60px;
            background: transparent !important;
            border: none !important;
        }
        .marker-pulse {
            position: absolute; 
            top: 50%; 
            left: 50%;
            transform: translate(-50%, -50%);
            width: 80px; 
            height: 80px;
            background: rgba(255, 215, 0, 0.3);
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        .marker-dot {
            position: absolute; 
            top: 50%; 
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 40px;
            z-index: 1000;
            filter: drop-shadow(0 0 10px rgba(255, 215, 0, 0.8));
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

function loadHistoricalData() {
    fetch('/api/recent')
        .then(res => res.json())
        .then(data => {
            if (!chart) return;
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

function initSocketIO() {
    socket = io({
        transports: ['websocket'],
        reconnection: true,
        reconnectionDelay: 1000,
        reconnectionAttempts: 10
    });

    socket.on('connect', function() {
        console.log('✅ Socket.IO connesso');
        const dot = document.getElementById('connectionDot');
        const text = document.getElementById('statusText');
        if (dot) dot.classList.add('connected');
        if (text) text.textContent = 'Connesso';
    });

    socket.on('disconnect', function() {
        console.log('⚠️ Socket.IO disconnesso');
        const dot = document.getElementById('connectionDot');
        const text = document.getElementById('statusText');
        if (dot) dot.classList.remove('connected');
        if (text) text.textContent = 'Disconnesso';
    });

    socket.on('new_heart_rate', function(data) {
        console.log('📡 Dati ricevuti:', data);
        const bpm = data.heart_rate;
        const bpmEl = document.getElementById('currentBpm');
        const updateEl = document.getElementById('lastUpdate');
        if (bpmEl) bpmEl.textContent = bpm;
        if (updateEl) updateEl.textContent = 'Aggiornato ora';
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

document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Inizializzazione dashboard...');
    
    setTimeout(() => {
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
    }, 100);
});
