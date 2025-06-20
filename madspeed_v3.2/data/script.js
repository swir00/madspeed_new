const gpsSignalEl = document.getElementById('gps-signal'),
    maxSpeedEl = document.getElementById('max-speed'),
    avgSpeedEl = document.getElementById('avg-speed'),
    currentSpeedEl = document.getElementById('current-speed'),
    distanceEl = document.getElementById('distance'),
    loggingStatusEl = document.getElementById('logging-status'),
    batteryContainerEl = document.getElementById('battery-status'),
    batteryLevelEl = batteryContainerEl.querySelector('.battery-level'),
    batteryPercentEl = batteryContainerEl.querySelector('.battery-percent'),
    resetBtn = document.getElementById('reset-btn'),
    startBtn = document.getElementById('start-btn'),
    stopBtn = document.getElementById('stop-btn'),
    downloadCsvBtn = document.getElementById('download-csv-btn'),
    zoomInXBtn = document.getElementById('zoom-in-x-btn'),
    zoomOutXBtn = document.getElementById('zoom-out-x-btn'),
    zoomInYBtn = document.getElementById('zoom-in-y-btn'),
    zoomOutYBtn = document.getElementById('zoom-out-y-btn'),
    resetZoomBtn = document.getElementById('reset-zoom-btn'),
    panXSlider = document.getElementById('pan-x-slider'),
    panYSlider = document.getElementById('pan-y-slider'),
    bars = Array.from(gpsSignalEl.querySelectorAll('.bar'));

// --- Nowe elementy dla menu hamburger i ustawień ---
const hamburgerButton = document.querySelector('.hamburger'),
    mainNav = document.querySelector('.main-nav'),
    navButtons = document.querySelectorAll('.nav-button'),
    mainSection = document.getElementById('main-section'),
    settingsSection = document.getElementById('settings-section'),
    spiffsTotalEl = document.getElementById('spiffs-total'),
    spiffsUsedEl = document.getElementById('spiffs-used'),
    spiffsPercentEl = document.getElementById('spiffs-percent'),
    spiffsProgressBar = document.getElementById('spiffs-progress-bar'),
    wifiSsidPrefixInput = document.getElementById('wifi-ssid-prefix'),
    wifiSsidMacSuffixSpan = document.getElementById('wifi-ssid-mac-suffix'),
    wifiPasswordPrefixInput = document.getElementById('wifi-password-prefix'),
    wifiPasswordMacSuffixSpan = document.getElementById('wifi-password-mac-suffix'),
    wifiSettingsForm = document.getElementById('wifi-settings-form'),
    wifiStatusMessage = document.getElementById('wifi-status-message');


let liveDataInterval,
    settingsDataInterval, // Nowy interwał dla danych ustawień
    allChartData = [],
    fullXRange = {
        min: 0,
        max: 100
    },
    fullYRange = {
        min: 0,
        max: 10
    },
    basePanOffset = {
        x: 0,
        y: 0
    };

const ctx = document.getElementById('speedChart').getContext('2d'),
    speedChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Prędkość (km/h)',
                data: [],
                borderColor: '#2196f3',
                borderWidth: 2,
                fill: false,
                tension: 0.2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: {
                duration: 0
            },
            scales: {
                x: {
                    type: 'linear',
                    position: 'bottom',
                    title: {
                        display: true,
                        text: 'Dystans (m)'
                    },
                    ticks: {
                        callback: function(l) {
                            return 'number' == typeof l && !isNaN(l) ? Math.round(l) + ' m' : ''
                        }
                    },
                    min: 0,
                    max: 100
                },
                y: {
                    title: {
                        display: true,
                        text: 'Prędkość (km/h)'
                    },
                    beginAtZero: true,
                    min: 0,
                    max: 10
                }
            },
            plugins: {
                zoom: {
                    pan: {
                        enabled: false // Pan enabled via sliders
                    },
                    zoom: {
                        wheel: {
                            enabled: true
                        },
                        pinch: {
                            enabled: true
                        },
                        drag: {
                            enabled: true,
                            borderColor: 'rgb(54, 162, 235)',
                            borderWidth: 2,
                            backgroundColor: 'rgba(54, 162, 235, 0.2)'
                        },
                        mode: 'xy',
                        doubleClick: {
                            enabled: false
                        }
                    }
                }
            }
        }
    });

// --- NOWA FUNKCJA: Przełączanie sekcji ---
function showSection(sectionId) {
    // Ukryj wszystkie sekcje zawartości
    const sections = document.querySelectorAll('.content-section');
    sections.forEach(section => {
        section.classList.remove('active');
    });

    // Pokaż wybraną sekcję
    document.getElementById(sectionId).classList.add('active');

    // Aktywuj przycisk nawigacyjny
    navButtons.forEach(button => {
        button.classList.remove('active');
        if (button.dataset.section === sectionId) {
            button.classList.add('active');
        }
    });

    // Zamknij menu hamburgera po wybraniu sekcji (na małych ekranach)
    if (window.innerWidth < 600) { // Dopasuj do breakpointu w CSS
        mainNav.classList.remove('is-active');
        hamburgerButton.classList.remove('is-active');
    }

    // Włącz/wyłącz interwały odświeżania w zależności od aktywnej sekcji
    if (sectionId === 'main-section') {
        if (!liveDataInterval) {
            liveDataInterval = setInterval(fetchAndUpdateLiveData, 1000);
            fetchAndUpdateLiveData(); // Odśwież natychmiast po włączeniu
        }
        if (settingsDataInterval) {
            clearInterval(settingsDataInterval);
            settingsDataInterval = null;
        }
    } else if (sectionId === 'settings-section') {
        if (liveDataInterval) {
            clearInterval(liveDataInterval);
            liveDataInterval = null;
        }
        if (!settingsDataInterval) {
            settingsDataInterval = setInterval(fetchSettingsData, 2000); // Odświeżaj ustawienia rzadziej
            fetchSettingsData(); // Odśwież natychmiast po włączeniu
        }
    }
}

// --- NOWA FUNKCJA: Pobieranie i aktualizacja danych ustawień ---
async function fetchSettingsData() {
    try {
        const response = await fetch('/settings');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        
        // Aktualizacja danych SPIFFS
        updateSpiffsDisplay(data.spiffsTotal, data.spiffsUsed);

        // Aktualizacja pól Wi-Fi
        const currentSsid = data.currentSsid || '';
        const currentPassword = data.currentPassword || '';
        const macSuffix = data.macAddressSuffix || ''; // Upewnij się, że ESP32 to wysyła

        wifiSsidMacSuffixSpan.textContent = macSuffix;
        wifiPasswordMacSuffixSpan.textContent = macSuffix;

        // Ustaw prefiksy na podstawie pełnego SSID/hasła
        // Jeśli pełne SSID zawiera sufiks MAC, wytnij prefix. W przeciwnym razie użyj całego SSID.
        if (currentSsid.endsWith(macSuffix) && macSuffix.length > 0) {
            wifiSsidPrefixInput.value = currentSsid.substring(0, currentSsid.length - macSuffix.length);
        } else {
            wifiSsidPrefixInput.value = currentSsid;
        }
        
        if (currentPassword.endsWith(macSuffix) && macSuffix.length > 0) {
            wifiPasswordPrefixInput.value = currentPassword.substring(0, currentPassword.length - macSuffix.length);
        } else {
            wifiPasswordPrefixInput.value = currentPassword;
        }

    } catch (error) {
        console.error('[fetchSettingsData] Błąd pobierania danych ustawień:', error);
        spiffsTotalEl.textContent = '-- MB';
        spiffsUsedEl.textContent = '-- MB';
        spiffsPercentEl.textContent = '--%';
        spiffsProgressBar.style.width = '0%';
        spiffsProgressBar.classList.remove('low', 'medium', 'high');
        
        wifiSsidPrefixInput.value = '';
        wifiSsidMacSuffixSpan.textContent = '';
        wifiPasswordPrefixInput.value = '';
        wifiPasswordMacSuffixSpan.textContent = '';
    }
}

// --- NOWA FUNKCJA: Aktualizacja wyświetlania pamięci SPIFFS ---
function updateSpiffsDisplay(totalBytes, usedBytes) {
    const totalMB = (totalBytes / (1024 * 1024)).toFixed(2);
    const usedMB = (usedBytes / (1024 * 1024)).toFixed(2);
    const percentUsed = totalBytes > 0 ? ((usedBytes / totalBytes) * 100).toFixed(0) : 0;

    spiffsTotalEl.textContent = `${totalMB} MB`;
    spiffsUsedEl.textContent = `${usedMB} MB`;
    spiffsPercentEl.textContent = `${percentUsed}%`;

    spiffsProgressBar.style.width = `${percentUsed}%`;
    spiffsProgressBar.classList.remove('low', 'medium', 'high');
    if (percentUsed >= 90) {
        spiffsProgressBar.classList.add('low'); // Czerwony dla >90%
    } else if (percentUsed >= 70) {
        spiffsProgressBar.classList.add('medium'); // Żółty dla >70%
    } else {
        spiffsProgressBar.classList.add('high'); // Zielony dla <70%
    }
}


function parseCsv(csvText) {
    const lines = csvText.split('\n').filter(line => line.trim() !== '');
    const data = [];

    if (lines.length > 1) {
        for (let i = 1; i < lines.length; i++) {
            const parts = lines[i].split(',');
            if (parts.length === 3) {
                data.push({
                    timestamp: parseInt(parts[0]),
                    speed: parseFloat(parts[1]),
                    distance: parseInt(parts[2])
                });
            } else {
                console.warn(`[parseCsv] Pomięto wiersz o nieprawidłowej liczbie kolumn: ${lines[i]}`);
            }
        }
    }
    return data;
}

function updateFullRangesAndSliders() {
    if (allChartData.length === 0) {
        fullXRange = {
            min: 0,
            max: 100
        };
        fullYRange = {
            min: 0,
            max: 10
        };
    } else {
        const distances = allChartData.map(l => parseInt(l.distance)).filter(d => !isNaN(d));
        const speeds = allChartData.map(l => parseFloat(l.speed)).filter(s => !isNaN(s) && s >= 0);

        fullXRange = {
            min: distances.length > 0 ? Math.min(...distances, 0) : 0,
            max: distances.length > 0 ? Math.max(...distances, 100) : 100
        };
        fullYRange = {
            min: speeds.length > 0 ? Math.min(...speeds, 0) : 0,
            max: speeds.length > 0 ? Math.max(...speeds, 10) : 10
        };

        if (fullYRange.max === 0 && speeds.length > 0) {
            fullYRange.max = 10;
        }
    }

    panXSlider.min = -100;
    panXSlider.max = 100;
    panYSlider.min = -100;
    panYSlider.max = 100;
    panXSlider.value = 0;
    panYSlider.value = 0;
    basePanOffset = {
        x: 0,
        y: 0
    };

    speedChart.resetZoom();
    speedChart.options.scales.x.min = fullXRange.min;
    speedChart.options.scales.x.max = fullXRange.max;
    speedChart.options.scales.y.min = fullYRange.min;
    speedChart.options.scales.y.max = fullYRange.max;
    speedChart.update('none');
    applyChartPan();
}

function applyChartPan() {
    if (allChartData.length === 0) {
        speedChart.options.scales.x.min = fullXRange.min;
        speedChart.options.scales.x.max = fullXRange.max;
        speedChart.options.scales.y.min = fullYRange.min;
        speedChart.options.scales.y.max = fullYRange.max;
        return speedChart.update('none');
    }

    const chart = speedChart;
    const xScale = chart.scales.x;
    const yScale = chart.scales.y;

    const currentXRangeWidth = xScale.max - xScale.min;
    const currentYRangeHeight = yScale.max - yScale.min;

    const fullXCenter = (fullXRange.min + fullXRange.max) / 2;
    const fullYCenter = (fullYRange.min + fullYRange.max) / 2;

    let panLimitX = (fullXRange.max - fullXRange.min) / 2 - currentXRangeWidth / 2;
    let panLimitY = (fullYRange.max - fullYRange.min) / 2 - currentYRangeHeight / 2;

    if (panLimitX < 0 || Math.abs(panLimitX) < 0.001) panLimitX = 0;
    if (panLimitY < 0 || Math.abs(panLimitY) < 0.001) panLimitY = 0;

    const panXNormalized = basePanOffset.x + panXSlider.value / 100;
    const panYNormalized = basePanOffset.y + panYSlider.value / 100;

    const clampedPanX = Math.min(1, Math.max(-1, panXNormalized));
    const clampedPanY = Math.min(1, Math.max(-1, panYNormalized));

    const newXCenter = fullXCenter + panLimitX * clampedPanX;
    const newYCenter = fullYCenter + panLimitY * clampedPanY;

    chart.options.scales.x.min = newXCenter - currentXRangeWidth / 2;
    chart.options.scales.x.max = newXCenter + currentXRangeWidth / 2;
    chart.options.scales.y.min = newYCenter - currentYRangeHeight / 2;
    chart.options.scales.y.max = newYCenter + currentYRangeHeight / 2;

    chart.update('none');
}

function voltageToPercent(voltage) {
    const minVoltage = 3;
    const maxVoltage = 4.2;
    let percent = (voltage - minVoltage) / (maxVoltage - minVoltage) * 100;
    return Math.min(100, Math.max(0, Math.round(percent)));
}

function updateBatteryDisplay(percent) {
    batteryPercentEl.textContent = `${percent}%`;
    batteryLevelEl.style.width = `${percent}%`;
    batteryLevelEl.classList.remove('low', 'medium', 'high');
    if (percent <= 20) {
        batteryLevelEl.classList.add('low');
    } else if (percent <= 50) {
        batteryLevelEl.classList.add('medium');
    } else {
        batteryLevelEl.classList.add('high');
    }
}

function updateGpsSignal(level) {
    bars.forEach((bar, index) => bar.classList.toggle('active', index < level));
}

async function fetchAndUpdateLiveData() {
    try {
        const response = await fetch('/data');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();

        updateGpsSignal(data.gpsQualityLevel || 0);
        const batteryPercent = voltageToPercent(data.battery);
        updateBatteryDisplay(batteryPercent);

        maxSpeedEl.textContent = `${data.maxSpeed.toFixed(1)} km/h`;
        avgSpeedEl.textContent = `${data.avgSpeed.toFixed(1)} km/h`;
        currentSpeedEl.textContent = `${data.currentSpeed.toFixed(1)} km/h`;
        const distanceMeters = Math.round(data.distance * 1000);
        distanceEl.textContent = `${distanceMeters} m`;
        loggingStatusEl.textContent = data.isLoggingActive ? "Aktywne (nagrywanie)" : "Nieaktywne";

    } catch (error) {
        console.error('[fetchAndUpdateLiveData] Błąd pobierania danych (możliwy brak połączenia z ESP32):', error);
        updateGpsSignal(0);
        updateBatteryDisplay(0);
        currentSpeedEl.textContent = `-- km/h`;
        maxSpeedEl.textContent = `-- km/h`;
        avgSpeedEl.textContent = `-- km/h`;
        distanceEl.textContent = `-- m`;
        loggingStatusEl.textContent = "Błąd połączenia";
    }
}

async function processLogDataAndDrawChart(showAlertOnError = false) {
    try {
        const response = await fetch('/download_csv');
        if (!response.ok) {
            const errorText = await response.text();
            if (showAlertOnError) {
                alert("Nie udało się pobrać danych logu dla wykresu. Sprawdź połączenie z ESP32 i logi w konsoli deweloperskiej. Szczegóły w konsoli.");
            }
            throw new Error(`HTTP error! status: ${response.status}. Response: ${errorText}`);
        }

        const csvText = await response.text();
        allChartData = parseCsv(csvText);

        speedChart.data.labels = [];
        speedChart.data.datasets[0].data = [];

        let lastDistance = -1;
        let lastSpeed = -1;
        const MIN_DISTANCE_DIFF = 1;
        const MIN_SPEED_DIFF = 0.5;

        if (allChartData.length === 0) {
            console.warn("[processLogDataAndDrawChart] Otrzymano puste dane z serwera. Wykres będzie pusty.");
        } else {
            allChartData.forEach(entry => {
                const distance = parseInt(entry.distance);
                const speed = parseFloat(entry.speed);

                if (speed >= 0 && (
                            lastDistance === -1 ||
                            Math.abs(distance - lastDistance) >= MIN_DISTANCE_DIFF ||
                            Math.abs(speed - lastSpeed) >= MIN_SPEED_DIFF
                        )) {
                    speedChart.data.labels.push(distance);
                    speedChart.data.datasets[0].data.push(speed);
                    lastDistance = distance;
                    lastSpeed = speed;
                }
            });
        }

        updateFullRangesAndSliders();
        speedChart.update();

    } catch (error) {
        console.error('[processLogDataAndDrawChart] Błąd pobierania logu lub parsowania CSV:', error);
        if (showAlertOnError && !error.message.includes("HTTP error!")) {
            alert("Wystąpił błąd podczas przetwarzania danych logu. Sprawdź konsolę deweloperską.");
        }
    }
}

// Chart Zoom and Pan Callbacks
speedChart.options.plugins.zoom.onZoom = function({
    chart: l
}) {
    if (allChartData.length === 0 || fullXRange.max <= fullXRange.min || fullYRange.max <= fullYRange.min) {
        panXSlider.value = 0;
        panYSlider.value = 0;
        basePanOffset = {
            x: 0,
            y: 0
        };
        return;
    }
    const a = (l.scales.x.min + l.scales.x.max) / 2,
        t = (l.scales.y.min + l.scales.y.max) / 2,
        e = (fullXRange.min + fullXRange.max) / 2,
        n = (fullYRange.min + fullYRange.max) / 2,
        s = l.scales.x.max - l.scales.x.min,
        o = l.scales.y.max - l.scales.y.min;
    let i = (fullXRange.max - fullXRange.min) / 2 - s / 2,
        c = (fullYRange.max - fullYRange.min) / 2 - o / 2;
    i <= 0 && (i = .001), c <= 0 && (c = .001), basePanOffset.x = (a - e) / i, basePanOffset.y = (t - n) / c, panXSlider.value = 0, panYSlider.value = 0
};

// Zoom Buttons
zoomInXBtn.addEventListener('click', (() => {
    speedChart.zoom({
        x: 1.1
    })
}));
zoomOutXBtn.addEventListener('click', (() => {
    speedChart.zoom({
        x: .9
    })
}));
zoomInYBtn.addEventListener('click', (() => {
    speedChart.zoom({
        y: 1.1
    })
}));
zoomOutYBtn.addEventListener('click', (() => {
    speedChart.zoom({
        y: .9
    })
}));
resetZoomBtn.addEventListener('click', (() => {
    speedChart.resetZoom();
    speedChart.options.scales.x.min = fullXRange.min;
    speedChart.options.scales.x.max = fullXRange.max;
    speedChart.options.scales.y.min = fullYRange.min;
    speedChart.options.scales.y.max = fullYRange.max;
    speedChart.update('none');
    basePanOffset = {
        x: 0,
        y: 0
    };
    panXSlider.value = 0;
    panYSlider.value = 0;
    applyChartPan();
}));

// Pan Sliders
panXSlider.addEventListener('input', applyChartPan);
panXSlider.addEventListener('mouseup', () => {
    const l = speedChart,
        a = l.scales.x,
        t = (a.min + a.max) / 2,
        e = (fullXRange.min + fullXRange.max) / 2,
        n = a.max - a.min;
    let s = (fullXRange.max - fullXRange.min) / 2 - n / 2;
    s <= 0 && (s = .001), basePanOffset.x = (t - e) / s, animateSliderToZero(panXSlider)
});
panXSlider.addEventListener('touchend', () => {
    const l = speedChart,
        a = l.scales.x,
        t = (a.min + a.max) / 2,
        e = (fullXRange.min + fullXRange.max) / 2,
        n = a.max - a.min;
    let s = (fullXRange.max - fullXRange.min) / 2 - n / 2;
    s <= 0 && (s = .001), basePanOffset.x = (t - e) / s, animateSliderToZero(panXSlider)
});
panYSlider.addEventListener('input', applyChartPan);
panYSlider.addEventListener('mouseup', () => {
    const l = speedChart,
        a = l.scales.y,
        t = (a.min + a.max) / 2,
        e = (fullYRange.min + fullYRange.max) / 2,
        n = a.max - a.min;
    let s = (fullYRange.max - fullYRange.min) / 2 - n / 2;
    s <= 0 && (s = .001), basePanOffset.y = (t - e) / s, animateSliderToZero(panYSlider)
});
panYSlider.addEventListener('touchend', () => {
    const l = speedChart,
        a = l.scales.y,
        t = (a.min + a.max) / 2,
        e = (fullYRange.min + fullYRange.max) / 2,
        n = a.max - a.min;
    let s = (fullYRange.max - fullYRange.min) / 2 - n / 2;
    s <= 0 && (s = .001), basePanOffset.y = (t - e) / s, animateSliderToZero(panYSlider)
});

function animateSliderToZero(slider) {
    const startValue = parseInt(slider.value);
    const duration = 200;
    const startTime = performance.now();

    function easeOutCubic(t) {
        return (--t) * t * t + 1;
    }

    function animate(currentTime) {
        const elapsedTime = currentTime - startTime;
        const progress = Math.min(elapsedTime / duration, 1);
        slider.value = startValue * (1 - easeOutCubic(progress));

        if (progress < 1) {
            requestAnimationFrame(animate);
        } else {
            slider.value = 0;
        }
    }
    requestAnimationFrame(animate);
}


// Button Event Listeners
startBtn.addEventListener('click', async () => {
    try {
        const response = await fetch('/start', {
            method: 'POST'
        });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        speedChart.data.labels = [];
        speedChart.data.datasets[0].data = [];
        speedChart.update('none');
        allChartData = [];
        updateFullRangesAndSliders();
        fetchAndUpdateLiveData();
    } catch (error) {
        console.error("[startBtn] Nie udało się wysłać komendy START:", error);
        alert("Nie udało się rozpocząć nagrywania. Sprawdź połączenie z ESP32.");
    }
});

stopBtn.addEventListener('click', async () => {
    try {
        const response = await fetch('/stop', {
            method: 'POST'
        });
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`HTTP error! status: ${response.status}. Response: ${errorText}`);
        }

        await new Promise(resolve => setTimeout(resolve, 100));

        await processLogDataAndDrawChart(true);
        fetchAndUpdateLiveData();

    } catch (error) {
        console.error("[stopBtn] Nie udało się zatrzymać nagrywania lub pobrać danych:", error);
        if (!error.message.includes("HTTP error!")) {
            alert("Nie udało się zatrzymać nagrywania lub pobrać danych. Sprawdź połączenie z ESP32 i konsolę deweloperską.");
        }
    }
});

resetBtn.addEventListener('click', async () => {
    if (confirm('Czy na pewno chcesz zresetować statystyki i usunąć dane logowania?')) {
        try {
            const response = await fetch('/reset', {
                method: 'POST'
            });
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            maxSpeedEl.textContent = `-- km/h`;
            avgSpeedEl.textContent = `-- km/h`;
            currentSpeedEl.textContent = `-- km/h`;
            distanceEl.textContent = `-- m`;
            loggingStatusEl.textContent = "Nieaktywne";
            updateBatteryDisplay(0);
            updateGpsSignal(0);

            speedChart.data.labels = [];
            speedChart.data.datasets[0].data = [];
            speedChart.update('none');
            allChartData = [];

            updateFullRangesAndSliders();
            speedChart.resetZoom();

            fetchAndUpdateLiveData();

        } catch (error) {
            console.error("[resetBtn] Nie udało się wysłać komendy RESET:", error);
            alert("Nie udało się zresetować danych. Sprawdź połączenie z ESP32.");
        }
    }
});

downloadCsvBtn.addEventListener('click', (() => {
    if (allChartData.length === 0) {
        console.warn("[downloadCsvBtn] Nie ma danych w pamięci przeglądarki (allChartData jest puste). Spróbuję pobrać bezpośrednio z serwera.");
    }
    window.location.href = '/download_csv';
}));

// --- NOWA OBSŁUGA FORMULARZA WI-FI ---
wifiSettingsForm.addEventListener('submit', async (event) => {
    event.preventDefault(); // Zapobieganie domyślnej wysyłce formularza

    const ssidPrefix = wifiSsidPrefixInput.value.trim();
    const passwordPrefix = wifiPasswordPrefixInput.value.trim();
    const macSuffix = wifiSsidMacSuffixSpan.textContent.trim(); // Sufiks MAC jest stały i pobierany z ESP32

    if (!ssidPrefix || !passwordPrefix) {
        showMessage(wifiStatusMessage, 'Nazwa sieci i hasło nie mogą być puste.', 'error');
        return;
    }

    const newSsid = ssidPrefix + macSuffix;
    const newPassword = passwordPrefix + macSuffix;

    try {
        const response = await fetch('/update_wifi_config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ ssid: newSsid, password: newPassword })
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`HTTP error! status: ${response.status}. Response: ${errorText}`);
        }

        const result = await response.json();
        if (result.success) {
            showMessage(wifiStatusMessage, 'Ustawienia Wi-Fi zostały zapisane. ESP32 zrestartuje się.', 'success');
            // Opcjonalnie: można dodać setTimeout na restart strony po restarcie ESP32
            setTimeout(() => location.reload(), 5000); 
        } else {
            showMessage(wifiStatusMessage, `Błąd: ${result.message}`, 'error');
        }
    } catch (error) {
        console.error('[wifiSettingsForm] Błąd wysyłania ustawień Wi-Fi:', error);
        showMessage(wifiStatusMessage, `Błąd połączenia lub serwera: ${error.message}`, 'error');
    }
});

function showMessage(element, message, type) {
    element.textContent = message;
    element.className = `status-message ${type}`; // Resetuj i ustaw klasy
    element.style.display = 'block';
    setTimeout(() => {
        element.style.display = 'none';
    }, 5000); // Ukryj wiadomość po 5 sekundach
}

// --- INITIALIZATION ---
document.addEventListener('DOMContentLoaded', function() {
    // Ustaw bieżący rok w stopce
    const currentYearEl = document.getElementById('current-year');
    if (currentYearEl) {
        currentYearEl.textContent = (new Date).getFullYear();
    }

    // Obsługa przełączania menu hamburgera
    hamburgerButton.addEventListener('click', () => {
        mainNav.classList.toggle('is-active');
        hamburgerButton.classList.toggle('is-active');
    });

    // Obsługa przełączania sekcji menu
    navButtons.forEach(button => {
        button.addEventListener('click', () => {
            showSection(button.dataset.section);
        });
    });

    // Uruchomienie domyślnej sekcji
    showSection('main-section'); 
    processLogDataAndDrawChart(false);
});