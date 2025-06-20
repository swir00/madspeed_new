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

let liveDataInterval,
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

// --- NOWA FUNKCJA: Parsowanie danych CSV ---
function parseCsv(csvText) {
    const lines = csvText.split('\n').filter(line => line.trim() !== ''); // Usuń puste linie
    const data = [];

    if (lines.length > 1) { // Sprawdź, czy są dane poza nagłówkiem
        // Pomijamy nagłówek (pierwszą linię), która powinna być "Timestamp_s,Speed_kmh,Distance_m"
        for (let i = 1; i < lines.length; i++) {
            const parts = lines[i].split(',');
            if (parts.length === 3) { // Oczekujemy 3 kolumn: Timestamp, Speed, Distance
                data.push({
                    timestamp: parseInt(parts[0]),
                    speed: parseFloat(parts[1]),
                    distance: parseInt(parts[2]) // Distance w metrach
                });
            } else {
                console.warn(`[parseCsv] Pomięto wiersz o nieprawidłowej liczbie kolumn: ${lines[i]}`);
            }
        }
    }
    return data;
}

function updateFullRangesAndSliders() {
    console.log("[updateFullRangesAndSliders] Aktualizuję zakresy wykresu na podstawie danych.");
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
            min: distances.length > 0 ? Math.min(...distances, 0) : 0, // ensure min is not negative if all distances are positive
            max: distances.length > 0 ? Math.max(...distances, 100) : 100
        };
        fullYRange = {
            min: speeds.length > 0 ? Math.min(...speeds, 0) : 0, // ensure min is not negative
            max: speeds.length > 0 ? Math.max(...speeds, 10) : 10
        };

        // Ensure fullYRange.max is not 0 if there's data, to prevent division by zero or collapsed scale
        if (fullYRange.max === 0 && speeds.length > 0) {
            fullYRange.max = 10; // Default max if all speeds are 0
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

    speedChart.resetZoom(); // Reset zoom before applying new scales
    speedChart.options.scales.x.min = fullXRange.min;
    speedChart.options.scales.x.max = fullXRange.max;
    speedChart.options.scales.y.min = fullYRange.min;
    speedChart.options.scales.y.max = fullYRange.max;
    speedChart.update('none'); // Update chart to apply new scales
    applyChartPan(); // Re-apply pan offset if any
    console.log("[updateFullRangesAndSliders] Nowe zakresy X:", fullXRange, "Y:", fullYRange);
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

    // Ensure pan limits are not negative or too small
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
    const minVoltage = 2.5;
    const maxVoltage = 4.0;
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
            console.warn(`[fetchAndUpdateLiveData] Server responded with status: ${response.status}`);
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();

        updateGpsSignal(data.gpsQualityLevel || 0);
        const batteryPercent = voltageToPercent(data.battery);
        updateBatteryDisplay(batteryPercent);

        maxSpeedEl.textContent = `${data.maxSpeed.toFixed(1)} km/h`;
        avgSpeedEl.textContent = `${data.avgSpeed.toFixed(1)} km/h`;
        currentSpeedEl.textContent = `${data.currentSpeed.toFixed(1)} km/h`;
        const distanceMeters = Math.round(data.distance * 1000); // convert km to meters
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
        console.log("[processLogDataAndDrawChart] Pobieranie danych logu dla wykresu...");
        // *** KLUCZOWA ZMIANA: Poprawny URL do endpointu CSV ***
        const response = await fetch('/download_csv'); 
        console.log(`[processLogDataAndDrawChart] Status odpowiedzi z /download_csv: ${response.status}`);

        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[processLogDataAndDrawChart] Błąd odpowiedzi serwera dla /download_csv: ${response.status}. Response: ${errorText}`);
            if (showAlertOnError) {
                alert("Nie udało się pobrać danych logu dla wykresu. Sprawdź połączenie z ESP32 i logi w konsoli deweloperskiej. Szczegóły w konsoli.");
            }
            throw new Error(`HTTP error! status: ${response.status}. Response: ${errorText}`);
        }

        // *** KLUCZOWA ZMIANA: Użycie .text() do pobrania CSV i ręczne parsowanie ***
        const csvText = await response.text();
        console.log("[processLogDataAndDrawChart] Odebrano dane CSV. Parsowanie...");
        allChartData = parseCsv(csvText); 
        console.log(`[processLogDataAndDrawChart] Dane CSV sparsowane pomyślnie. Liczba wpisów: ${allChartData.length}`);

        if (allChartData.length > 0) {
            console.log("[processLogDataAndDrawChart] Pierwsze 5 surowych wpisów:", allChartData.slice(0, 5));
            console.log("[processLogDataAndDrawChart] Ostatnie 5 surowych wpisów:", allChartData.slice(-5));
        }

        speedChart.data.labels = [];
        speedChart.data.datasets[0].data = [];

        let lastDistance = -1;
        let lastSpeed = -1;
        const MIN_DISTANCE_DIFF = 1; // Minimalna zmiana dystansu (m) do dodania punktu
        const MIN_SPEED_DIFF = 0.5; // Minimalna zmiana prędkości (km/h) do dodania punktu

        if (allChartData.length === 0) {
            console.warn("[processLogDataAndDrawChart] Otrzymano puste dane z serwera. Wykres będzie pusty.");
        } else {
            let filteredPointsCount = 0;
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
                    filteredPointsCount++;
                } else {
                    console.log(`[processLogDataAndDrawChart] Punkt odrzucony (dystans: ${distance}, prędkość: ${speed}). Kryteria: D:${(distance - lastDistance).toFixed(2)}m (min ${MIN_DISTANCE_DIFF}m), S:${(speed - lastSpeed).toFixed(2)}km/h (min ${MIN_SPEED_DIFF}km/h)`);
                }
            });

            console.log(`[processLogDataAndDrawChart] Całkowita liczba punktów w surowych danych: ${allChartData.length}`);
            console.log(`[processLogDataAndDrawChart] Liczba punktów dodanych do wykresu po filtracji: ${filteredPointsCount}`);


            if (speedChart.data.labels.length === 0) {
                console.warn("[processLogDataAndDrawChart] Po filtrowaniu wykres jest pusty. Dane logu nie spełniają kryteriów filtracji.");
            } else {
                console.log(`[processLogDataAndDrawChart] Wykres zaktualizowany. Liczba punktów: ${speedChart.data.labels.length}.`);
            }
        }

        updateFullRangesAndSliders();
        speedChart.update();
        console.log(`[processLogDataAndDrawChart] Dane logu pobrane i naniesione na wykres. Liczba punktów na wykresie: ${speedChart.data.labels.length}`);

    } catch (error) {
        console.error('[processLogDataAndDrawChart] Błąd pobierania logu lub parsowania CSV:', error); // Zmieniono komunikat błędu
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
    console.log("[resetZoomBtn] Wykres i suwaki zresetowane.");
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
    const duration = 200; // milliseconds
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
            slider.value = 0; // Ensure it ends exactly at 0
        }
    }
    requestAnimationFrame(animate);
}


// Button Event Listeners
startBtn.addEventListener('click', async () => {
    try {
        console.log("[startBtn] Wysyłam komendę START do ESP32.");
        const response = await fetch('/start', {
            method: 'POST'
        });
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        console.log("[startBtn] Komenda START wysłana pomyślnie.");
        speedChart.data.labels = [];
        speedChart.data.datasets[0].data = [];
        speedChart.update('none');
        allChartData = [];
        updateFullRangesAndSliders();
        fetchAndUpdateLiveData(); // Odśwież dane na żywo od razu
    } catch (error) {
        console.error("[startBtn] Nie udało się wysłać komendy START:", error);
        alert("Nie udało się rozpocząć nagrywania. Sprawdź połączenie z ESP32.");
    }
});

stopBtn.addEventListener('click', async () => {
    try {
        console.log("[stopBtn] Wysyłam komendę STOP do ESP32.");
        const response = await fetch('/stop', {
            method: 'POST'
        });
        if (!response.ok) {
            const errorText = await response.text();
            console.error(`[stopBtn] Błąd odpowiedzi serwera dla /stop: ${response.status}. Response: ${errorText}`);
            throw new Error(`HTTP error! status: ${response.status}. Response: ${errorText}`);
        }
        console.log("[stopBtn] Komenda STOP wysłana pomyślnie. Dane powinny być zapisane na ESP32.");

        console.log("[stopBtn] Czekam 100ms na sfinalizowanie zapisu danych...");
        await new Promise(resolve => setTimeout(resolve, 100));

        console.log("[stopBtn] Wywołuję processLogDataAndDrawChart() w celu pobrania i narysowania logu...");
        await processLogDataAndDrawChart(true); // showAlertOnError jest true, jeśli chcesz alerty tylko dla błędów
        fetchAndUpdateLiveData(); // Odśwież dane na żywo po zakończeniu nagrywania

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
            console.log("[resetBtn] Wysyłam komendę RESET do ESP32.");
            const response = await fetch('/reset', {
                method: 'POST'
            });
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            console.log("[resetBtn] Komenda RESET wysłana pomyślnie.");

            // Resetowanie wszystkich parametrów w interfejsie użytkownika
            maxSpeedEl.textContent = `-- km/h`;
            avgSpeedEl.textContent = `-- km/h`;
            currentSpeedEl.textContent = `-- km/h`;
            distanceEl.textContent = `-- m`;
            loggingStatusEl.textContent = "Nieaktywne"; // Reset statusu logowania
            updateBatteryDisplay(0); // Reset baterii na 0% lub domyślny
            updateGpsSignal(0); // Reset sygnału GPS na 0

            // Resetowanie wykresu i danych
            speedChart.data.labels = [];
            speedChart.data.datasets[0].data = [];
            speedChart.update('none'); // Zaktualizuj wykres, aby był pusty
            allChartData = []; // Wyczyść bufor danych

            // Resetowanie zakresów i suwaków zoomu
            updateFullRangesAndSliders(); // To automatycznie zresetuje zakresy do domyślnych
            speedChart.resetZoom(); // Upewnij się, że zoom jest zresetowany

            // Wywołaj odświeżanie danych na żywo, aby pobrać aktualny stan z ESP32 (np. czy logger jest naprawdę nieaktywny)
            fetchAndUpdateLiveData();

            console.log("[resetBtn] Wszystkie parametry i wykres zostały zresetowane.");
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
    console.log("[downloadCsvBtn] Wysłano żądanie pobrania pliku CSV z serwera.");
    window.location.href = '/download_csv'; // To wywoła pobranie pliku z ESP32
}));

// Initial Data Fetching
liveDataInterval = setInterval(fetchAndUpdateLiveData, 1000); // Odświeżaj dane na żywo co sekundę
fetchAndUpdateLiveData(); // Pobierz dane na żywo natychmiast po załadowaniu strony
processLogDataAndDrawChart(false); // Spróbuj załadować dane logu na start (bez alertów błędów, jeśli serwer nie jest aktywny)

// Footer Current Year
document.addEventListener('DOMContentLoaded', function() {
    const currentYearEl = document.getElementById('current-year');
    if (currentYearEl) {
        currentYearEl.textContent = (new Date).getFullYear();
    }
});