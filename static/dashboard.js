console.log('📊 Dashboard script caricato');

let chart;
let socket;
let currentBpm = 0;
let map;
let marker;

// Inizializza grafico Chart.js
function initChart() {
    var ctx = document.getElementById('heartRateChart');
    if (!ctx) {
        console.error('❌ Elemento canvas non trovato');
        return;
    }
    
    chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Heart Rate (BPM)',
                data: [],
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

// Inizializza mappa Leaflet
function initMap() {
    const mapElement = document.getElementById('map');
    if (!mapElement) {
        console.error('❌ Elemento mappa non trovato');
        return;
    }
    
    try {
        // Milano default
        map = L.map('map').setView([45.4642, 9.19], 13);
        
        // Tema scuro stile sportivo
        L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
            attribution: '© OpenStreetMap contributors © CARTO',
            maxZoom: 19,
            subdomains: 'abcd'
        }).addTo(map);
        
        // Marker personalizzato con pulse
        const markerHtml = `
            <div style="
                position: relative;
                width: 30px;
                height: 30px;
            ">
                <div style="
                    position: absolute;
                    width: 30px;
                    height: 30px;
                    background: rgba(6, 182, 212, 0.3);
                    border-radius: 50%;
                    animation: pulse 2s infinite;
                "></div>
                <div style="
                    position: absolute;
                    top: 5px;
                    left: 5px;
                    width: 20px;
                    height: 20px;
                    background: #06b6d4;
                    border: 3px solid white;
                    border-radius: 50%;
                    box-shadow: 0 0 20px rgba(6,182,212,0.8);
                "></div>
            </div>
        `;
        
        const customIcon = L.divIcon({
            className: 'custom-marker',
            html: markerHtml,
            iconSize: [30, 30],
            iconAnchor: [15, 15]
        });
        
        marker = L.marker([45.4642, 9.19], {icon: customIcon}).addTo(map);
        
        console.log('✅ Mappa inizializzata');
        
        // CSS per animazione pulse
        const style = document.createElement('style');
        style.textContent = `
            @keyframes pulse {
                0% {
                    transform: scale(1);
                    opacity: 1;
                }
                100% {
                    transform: scale(3);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(style);
        
    } catch (error) {
        console.error('❌ Errore inizializzazione mappa:', error);
    }
}

// (il resto del codice è già sintatticamente corretto e non richiede modifiche)