#define GNSS_RX_PIN 44          // D7 na pinoucie (GPIO44)
#define GNSS_TX_PIN 43          // D6 na pinoucie (GPIO43)
#define BATTERY_PIN 2           // A1 na pinoucie (GPIO2)

// Prototypy funkcji
void writeBufferToFile();
void readBatteryVoltage();
void sendPMTKCommand(const String& command);

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h> // Do deskryptora Client Characteristic Configuration (dla Notify)
#include <TinyGPSPlus.h>
#include <HardwareSerial.h>
#include <WiFi.h> // Wymagane dla HardwareSerial(x)

// Nagłówki do pobierania MAC adresu Bluetooth (potrzebne do dynamicznej nazwy BLE)
#include "esp_system.h"     // Dla esp_chip_info(), esp_random() i esp_read_mac()
#include "esp_mac.h"        // DODANO: Dla esp_read_mac() i ESP_MAC_BT
#include "esp_wifi.h"       // DODANO: Dla esp_wifi_stop() i WiFi.mode(WIFI_OFF)
#include "esp_bt.h"         // DODANO: Dla btStop()

#include <SPIFFS.h>         // Do obsługi systemu plików

// --- Parametry precyzji GNSS ---
#define MIN_DISTANCE_M      0.05  // Min. odległość do dodania do dystansu (w metrach)
#define MIN_SPEED_KMH       0.5  // Min. prędkość do uznania za ruch do obliczenia średniej/maksymalnej (w km/h)
#define MIN_SATS            8     // Min. liczba satelitów dla dobrej precyzji
#define MAX_HDOP            2.0   // Maks. HDOP (Horizontal Dilution of Precision) dla dobrej precyzji
#define MAX_FIX_AGE_MS      1000  // Maks. wiek poprawki GNSS (w milisekladach), po którym dane są uznawane za stare

const char* DATA_FILE = "/log.csv";    // Nazwa pliku do logowania danych

// --- UUID dla usług i charakterystyk BLE ---
// UWAGA: Te UUID są wygenerowane losowo. Upewnij się, że używasz TYCH SAMYCH w aplikacji Flutter!
#define SERVICE_UUID          "A2A00000-B1B1-C2C2-D3D3-E4E4E4E4E4E4" // Główna usługa MadSpeed
#define CHAR_UUID_CURRENT_DATA    "A2A00001-B1B1-C2C2-D3D3-E4E4E4E4E4E4" // Aktualne dane z GNSS/Baterii (Notify)
#define CHAR_UUID_CONTROL         "A2A00002-B1B1-C2C2-D3D3-E4E4E4E4E4E4" // Komendy sterujące (Write)
#define CHAR_UUID_LOG_DATA        "A2A00003-B1B1-C2C2-D3D3-E4E4E4E4E4E4" // Log Data (NOW NOTIFY for chunks)
#define CHAR_UUID_DEVICE_INFO     "A2A00004-B1B1-C2C2-D3D3-E4E4E4E4E4E4" // Informacje o urządzeniu (Read)

// --- Obiekty globalne BLE ---
BLEServer* pServer = NULL;
BLECharacteristic* pCurrentDataCharacteristic = NULL;
BLECharacteristic* pControlCharacteristic = NULL;
BLECharacteristic* pLogDataCharacteristic = NULL; // This will now be NOTIFY
BLECharacteristic* pDeviceInfoCharacteristic = NULL;
bool deviceConnected = false; // Flaga stanu połączenia BLE

// --- Obiekty globalne GNSS ---
HardwareSerial gnssSerial(1); // Użycie UART1 dla GNSS (piny 43 TX, 44 RX na ESP32S3 XIAO)
TinyGPSPlus gnss;              // Obiekt GNSS

// --- Zmienne globalne dla pomiarów ---
float liveMaxSpeed = 0;    // Maksymalna prędkość w czasie rzeczywistym
float liveSumSpeed = 0;    // Suma prędkości do obliczenia średniej w czasie rzeczywistym
int liveSpeedCount = 0;    // Licznik odczytów prędkości do obliczenia średniej w czasie rzeczywistym
float currentSpeedForDisplay = 0.0; // Aktualna prędkość do wysyłania przez BLE (globalna)

float distance_km = 0;
float lastLat = 0.0;
float lastLng = 0.0;
bool hasFirstFixForDistance = false; // NOWA FLAGA DO INICJALIZACJI DYSTANSY

// Zmienne do logowania offline
String measurementDataBuffer = ""; // Bufor na dane do zapisu do pliku
unsigned long lastFileWriteMillis = 0;
const unsigned long FILE_WRITE_INTERVAL_MS = 5000; // Interwał zapisu danych do pliku (5 sekund)
bool loggingActive = false; // Status logowania (czy dane są zapisywane do pliku)

// --- Zmienne dla cyklicznych powiadomień BLE ---
unsigned long lastBleNotifyMillis = 0;
// Zmienna, którą będziemy zmieniać w zależności od trybu (Speed Master / Trening)
unsigned long currentBleNotifyInterval = 1000; // Domyślnie 1 sekunda (1000 ms)

// --- Zmienne SSID/Password (ustawione na stałe lub puste, jeśli nie używasz WiFi) ---
String dynamicSsid = "NOT_APPLICABLE"; // Ustawione na stałe, ponieważ WiFi jest wyłączone
String dynamicPassword = "NOT_APPLICABLE"; // Ustawione na stałe, ponieważ WiFi jest wyłączone

// --- Zmienne dla odczytu baterii ---
float currentBatteryVoltage = 0.0; // Przechowuje ostatnie odczytane napięcie baterii
float batteryPercentage = 0.0;       // Przechowuje obliczony procent baterii
unsigned long lastBatteryReadMillis = 0;
const unsigned long BATTERY_READ_INTERVAL_MS = 15000; // Odczytuj baterię co 15 sekund

// --- Zmienne do transferu logów przez NOTIFY ---
const int MAX_BLE_PACKET_SIZE = 240; // Max size for BLE MTU (247 bytes - 7 bytes GATT header)
// Removed fullLogDataToTransfer as it will no longer hold the entire file in RAM
int currentLogTransferIndex = 0;
bool isLogTransferActive = false; // Flaga kontrolująca aktywny transfer logów
File logFile; // Global file object to stream logs
int _totalLinesInLogFile = 0; // NEW: To store total lines for metadata


// --- Klasy Callbacks dla BLE ---

// Klasa do obsługi zdarzeń serwera BLE (połączenie/rozłączenie)
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      Serial.println("[BLE] Urządzenie BLE połączone.");
      deviceConnected = true;
      // Możesz tutaj wyłączyć reklamowanie, jeśli chcesz tylko jedno połączenie naraz
      // BLEDevice::getAdvertising()->stop();
    };

    void onDisconnect(BLEServer* pServer) {
      Serial.println("[BLE] Urządzenie BLE rozłączone. Rozpoczynanie ponownej reklamy...");
      deviceConnected = false;
      // Close the log file if connection is lost during transfer
      if (logFile) {
        logFile.close();
        isLogTransferActive = false;
        Serial.println("[BLE LOG TRANSFER] Log file closed due to disconnection.");
      }
      // Rozpocznij ponownie reklamowanie, aby umożliwić nowe połączenia
      BLEDevice::startAdvertising();
    }
};

// Klasa do obsługi zdarzeń charakterystyk BLE (odczyt/zapis)
class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
    // Wywoływane, gdy aplikacja mobilna zapisuje dane do charakterystyki (np. komendy)
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue().c_str();
      if (value.length() > 0) {
        String command = String(value.c_str());
        Serial.print("[BLE] Otrzymano komendę: ");
        Serial.println(command);

        if (command == "START_LOG") {
          loggingActive = true;
          liveMaxSpeed = 0; liveSumSpeed = 0; liveSpeedCount = 0; // Resetuj zmienne real-time
          distance_km = 0;
          lastLat = 0.0; // Reset lastLat/Lng, będą zainicjalizowane pierwszym dobrym fixem
          lastLng = 0.0;
          hasFirstFixForDistance = false; // Resetuj flagę pierwszego fix'a

          measurementDataBuffer = ""; // Wyczyść bufor
          lastFileWriteMillis = millis();
          isLogTransferActive = false; // Zatrzymaj ewentualny transfer logów
          if (logFile) logFile.close(); // Ensure file is closed if logging restarts
          Serial.println("[LOG] Logowanie ROZPOCZĘTE.");
        } else if (command == "STOP_LOG") {
          loggingActive = false;
          writeBufferToFile(); // Zapisz pozostałe dane, które są w buforze
          Serial.println("[LOG] Logowanie ZATRZYMANE i dane zapisane.");
          // Po zatrzymaniu logowania, NIE rozpoczynamy automatycznie transferu.
          // Transfer zostanie zainicjalizowany przez komendę REQUEST_LOGS z Fluttera.
        } else if (command == "RESET") {
          loggingActive = false;
          // Po resecie, wracamy do trybu oszczędzania energii
          Serial.println("[POWER_CONFIG] Reset danych, powrót do 80 MHz.");
          setCpuFrequencyMhz(80);

          liveMaxSpeed = 0; liveSumSpeed = 0; liveSpeedCount = 0; // Resetuj zmienne real-time
          distance_km = 0;
          lastLat = 0.0;
          lastLng = 0.0;
          hasFirstFixForDistance = false; // Resetuj flagę pierwszego fix'a

          measurementDataBuffer = "";
          if (SPIFFS.exists(DATA_FILE)) {
            SPIFFS.remove(DATA_FILE); // Usuń plik logowania
            Serial.println("[SPIFFS] Plik logowania usunięty.");
          }
          isLogTransferActive = false; // Zatrzymaj ewentualny transfer logów
          if (logFile) logFile.close(); // Ensure file is closed
          Serial.println("[DATA] Dane zresetowane.");
        } else if (command == "REQUEST_LOGS") { // KOMENDA DLA FLUTTERA - Ulepszona logika
          Serial.println("[BLE] Otrzymano żądanie transferu logów.");

          // Zwiększ taktowanie CPU na czas transferu dla maksymalnej stabilności
          Serial.println("[POWER_CONFIG] Zwiększanie taktowania CPU do 240 MHz na czas transferu...");
          setCpuFrequencyMhz(240);

          if (logFile) { // If a file is already open, close it first
            logFile.close();
            Serial.println("[BLE LOG TRANSFER] Poprzedni strumień pliku logów zamknięty.");
          }

          if (!SPIFFS.exists(DATA_FILE)) {
            Serial.println("[BLE LOG TRANSFER] Plik logów nie istnieje. Wysyłam pustą listę.");
            pLogDataCharacteristic->setValue("END_EMPTY_LOG"); // Specific end for empty log
            pLogDataCharacteristic->notify();
            isLogTransferActive = false;
            _totalLinesInLogFile = 0; // Ensure count is zero
            return;
          }

          // --- NEW LOGIC: Count lines first (for metadata) ---
          File tempFile = SPIFFS.open(DATA_FILE, FILE_READ);
          if (!tempFile) {
              Serial.println("[BLE LOG TRANSFER ERROR] Błąd otwarcia pliku log.csv do zliczania linii!");
              pLogDataCharacteristic->setValue("ERROR: Failed to open file for counting lines."); // Send error message
              pLogDataCharacteristic->notify();
              isLogTransferActive = false;
              return;
          }
          _totalLinesInLogFile = 0;
          while (tempFile.available()) {
              if (tempFile.read() == '\n') {
                  _totalLinesInLogFile++;
              }
          }
          tempFile.close();
          Serial.print("[BLE LOG TRANSFER] Całkowita liczba linii w pliku: ");
          Serial.println(_totalLinesInLogFile);

          // --- Open file for actual transfer ---
          logFile = SPIFFS.open(DATA_FILE, FILE_READ);
          if (!logFile) {
            Serial.println("[BLE LOG TRANSFER ERROR] Błąd otwarcia pliku log.csv do odczytu!");
            pLogDataCharacteristic->setValue("ERROR: Failed to open file for reading data."); // Send error message
            pLogDataCharacteristic->notify();
            isLogTransferActive = false;
            return;
          }
          Serial.println("[BLE LOG TRANSFER] Plik logów otwarty do odczytu.");

          // Krok 1: Wyślij metadane z całkowitą liczbą linii.
          String metadata = "METADATA_LINES:" + String(_totalLinesInLogFile);
          pLogDataCharacteristic->setValue(metadata.c_str());
          pLogDataCharacteristic->notify();
          Serial.println("[BLE LOG TRANSFER] Wysłano METADATA: " + metadata);

          // Krok 2: Rozpocznij wysyłanie fragmentów logu w loop()
          currentLogTransferIndex = 0; // This will now act as line counter for progress
          isLogTransferActive = true; // Aktywuj transfer logów
          Serial.println("[BLE LOG TRANSFER] Rozpoczynanie strumieniowego transferu logów...");

        } else if (command == "SET_MODE:SPEEDMASTER") { // NOWA KOMENDA DLA TRYBU SPEED MASTER
          currentBleNotifyInterval = 200; // Ustaw interwał powiadomień na 200 ms (5 Hz)
          sendPMTKCommand("PMTK220,200"); // Ustaw częstotliwość GPS na 5 Hz
          Serial.println("[BLE] Tryb ustawiony na: Speed Master (interwał BLE: 200ms, GPS: 5Hz).");
        } else if (command == "SET_MODE:TRAINING") { // NOWA KOMENDA DLA TRYBU TRENINGU
          currentBleNotifyInterval = 2000; // Ustaw interwał powiadomień na 2000 ms (2 sekundy)
          sendPMTKCommand("PMTK220,1000"); // Ustaw częstotliwość GPS na 1 Hz
          Serial.println("[BLE] Tryb ustawiony na: Trening (interwał BLE: 2000ms, GPS: 1Hz).");
        }
        else {
            Serial.println("[BLE] Nieznana komenda.");
        }
      }
    }

    // Obsługa odczytu informacji o urządzeniu
    void onRead(BLECharacteristic *pCharacteristic) {
        if (pCharacteristic->getUUID().toString() == CHAR_UUID_DEVICE_INFO) {
            Serial.println("[BLE] Otrzymano żądanie odczytu informacji o urządzeniu.");
            readBatteryVoltage(); // Odczytaj i przelicz napięcie na procent
            // Usunięto odniesienia do dynamicSsid i dynamicPassword, ponieważ WiFi jest wyłączone
            String infoJson = "{\"ssid\":\"" + dynamicSsid + "\",\"password\":\"" + dynamicPassword + "\",\"isLoggingActive\":" + (loggingActive ? "true" : "false") + ",\"battery\":" + String(batteryPercentage, 0) + "}"; // Wysyłaj procent, a nie surowe napięcie
            pCharacteristic->setValue(infoJson.c_str());
            Serial.println("[BLE] Wysłano informacje o urządzeniu: " + infoJson);
        }
    }
};

// --- Funkcje pomocnicze ---

// Sterowanie diodą LED (dla Seeed Studio XIAO ESP32S3, potwierdzone active-LOW)
void setLedState() {
  if (loggingActive) {
    // Tryb logowania: dioda miga
    // Dioda LED pozostaje WYŁĄCZONA dla oszczędności, nawet podczas logowania.
    digitalWrite(LED_BUILTIN, HIGH); // Dioda LED wyłączona (active-LOW)
  } else {
    // Urządzenie włączone (bez logowania): dioda wyłączona
    digitalWrite(LED_BUILTIN, HIGH); // Dioda LED wyłączona (active-LOW)
  }
}

// Wysyłanie komend PMTK do modułu GNSS
void sendPMTKCommand(const String& command) {
  gnssSerial.print('$');
  gnssSerial.print(command);
  byte checksum = 0;
  for (int i = 0; i < command.length(); i++) {
    checksum ^= command.charAt(i);
  }
  gnssSerial.print('*');
  char checksumHex[3];
  sprintf(checksumHex, "%02X", checksum); // Formatowanie do dwóch cyfr HEX
  gnssSerial.println(checksumHex);
  Serial.print("[GNSS] Wysłano komendę PMTK: ");
  Serial.print(command);
  Serial.print("*");
  Serial.println(checksumHex);
}

// Konfiguracja modułu GNSS
void configureGNSS() {
  Serial.println("[GNSS] Rozpoczynam konfigurację modułu GNSS...");
  // Ustawienie początkowej częstotliwości GPS (domyślnie dla Treningu, lub Speed Master jeśli to domyślny tryb po starcie)
  sendPMTKCommand("PMTK220,1000"); // Początkowo ustaw 1 Hz dla GPS
  delay(100);
  sendPMTKCommand("PMTK353,1,1,1,0,0"); // Włączenie GPS, GLONASS i Galileo
  delay(100);
  // Włączenie potrzebnych zdań NMEA (GLL, GGA, RMC, VTG)
  sendPMTKCommand("PMTK314,0,1,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0");
  delay(100);
  Serial.println("[GNSS] Konfiguracja GNSS zakończona.");
}

// Dodawanie danych do bufora przed zapisem do pliku
// speed_for_log: to jest faktyczna prędkość odczytana z GNSS, bez zaokrąglania do zera dla wyświetlania
void addDataToBuffer(unsigned long timestamp, float speed_for_log, float distance_meters, float lat, float lng) {
  // Format: timestamp_s,speed_kmh,distance_m,latitude,longitude
  measurementDataBuffer += String(timestamp) + "," + String(speed_for_log, 2) + "," + String((int)round(distance_meters)) + "," + String(lat, 6) + "," + String(lng, 6) + "\n";
}

// Zapis bufora do pliku SPIFFS
void writeBufferToFile() {
  if (measurementDataBuffer.length() == 0) {
    Serial.println("[SPIFFS] Bufor danych pusty, nic do zapisu.");
    return;
  }

  File file = SPIFFS.open(DATA_FILE, FILE_APPEND);
  if (!file) {
    Serial.println("[SPIFFS ERROR] Błąd otwarcia pliku log.csv do zapisu!");
    return;
  }

  size_t bytesWritten = file.print(measurementDataBuffer);
  file.close();
  measurementDataBuffer = ""; // Wyczyść bufor po zapisie
  Serial.print("[SPIFFS] Bufor danych zapisany do pliku log.csv (");
  Serial.print(bytesWritten);
  Serial.println(" bajtów).");
}

// Funkcja do odczytu napięcia baterii i przeliczania na procent
void readBatteryVoltage() {
  float rawADC_sum = 0;
  int numReadings = 100;
  for (int i = 0; i < numReadings; i++) {
      rawADC_sum += analogRead(BATTERY_PIN);
      delayMicroseconds(10);
  }
  currentBatteryVoltage = rawADC_sum * (3.3f / 4095.0f) * 2.0f / numReadings; // Skorygowane dzielenie przez numReadings
  Serial.print("[BATT] Odczyt baterii: "); Serial.print(currentBatteryVoltage, 2); Serial.println("V");

  // Przeliczanie na procent: 3.3V = 0%, 4.0V = 100%
  const float minVoltage = 3.3;
  const float maxVoltage = 4.0;

  if (currentBatteryVoltage <= minVoltage) {
      batteryPercentage = 0.0;
  } else if (currentBatteryVoltage >= maxVoltage) {
      batteryPercentage = 100.0;
  } else {
      batteryPercentage = ((currentBatteryVoltage - minVoltage) / (maxVoltage - minVoltage)) * 100.0;
  }
  batteryPercentage = round(batteryPercentage); // Zaokrąglij do najbliższej liczby całkowitej
  Serial.print("[BATT] Procent baterii: "); Serial.print(batteryPercentage); Serial.println("%");
}


// --- Konfiguracja (Setup) ---
void setup() {
  Serial.begin(115200);
  Serial.println("\n--- Start MadSpeed Device ---");

  // Optymalizacja baterii: Dioda LED mignie raz na początku i zostanie wyłączona
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW); // Włącz LED (active-LOW)
  delay(500); // Trzymaj włączoną przez 0.5 sekundy
  digitalWrite(LED_BUILTIN, HIGH); // Wyłącz LED (active-LOW)
  Serial.println("[LED] Dioda LED włączona na krótko i wyłączona (optymalizacja baterii).");

  // --- Ograniczenie zużycia energii i zasobów ---
  // Wyłączenie Wi-Fi i BT Classic (BR/EDR)
  Serial.println("[POWER_SAVE] Wyłączanie WiFi i Bluetooth Classic...");
  WiFi.mode(WIFI_OFF);
  esp_wifi_stop();
  btStop();
  Serial.println("[POWER_SAVE] WiFi i Bluetooth Classic wyłączone.");

  // Domyślnie ustawiamy niskie taktowanie dla oszczędzania energii.
  // Zostanie ono dynamicznie zwiększone do 240 MHz na czas transferu logów.
  Serial.println("[POWER_CONFIG] Ustawianie domyślnego taktowania CPU na 80 MHz...");
  setCpuFrequencyMhz(80);
  Serial.println("[POWER_CONFIG] Taktowanie CPU ustawione na 80 MHz.");
  // --- Koniec optymalizacji ---


  // Inicjalizacja UART dla GNSS
  Serial.print("[GNSS] Inicjalizacja UART1 (RX:");
  Serial.print(GNSS_RX_PIN);
  Serial.print(", TX:");
  Serial.print(GNSS_TX_PIN);
  Serial.println(") z prędkością 9600.");
  gnssSerial.begin(9600, SERIAL_8N1, GNSS_RX_PIN, GNSS_TX_PIN);
  delay(1000);
  Serial.println("[GNSS] Oczekiwanie na stabilizację modułu GNSS (1s)...");

  configureGNSS(); // Konfiguracja GNSS (teraz początkowo 1 Hz dla GPS)

  Serial.print("[SPIFFS] Inicjalizacja systemu plików SPIFFS...");
  if (!SPIFFS.begin(true)) {
    Serial.println(" BŁĄD. Próbuję formatować...");
    SPIFFS.format();
    if (!SPIFFS.begin(true)) {
        Serial.println("[SPIFFS ERROR] Ponowna inicjalizacja SPIFFS nieudana. Restart za 5s.");
        delay(5000);
        ESP.restart();
    }
  }
  Serial.println(" OK. SPIFFS zainicjalizowany.");

  readBatteryVoltage();
  lastBatteryReadMillis = millis();

  // --- Konfiguracja BLE ---

  // Pobierz MAC adres Bluetooth
  uint8_t macBT[6];
  esp_read_mac(macBT, ESP_MAC_BT); // Użyj ESP_MAC_BT dla MAC adresu Bluetooth
  char macSuffix[7];
  // Formatowanie tylko ostatnich 3 bajtów dla krótszej, ale unikalnej nazwy
  snprintf(macSuffix, sizeof(macSuffix), "%02X%02X%02X", macBT[3], macBT[4], macBT[5]);
  String bleDeviceName = "MadSpeed_" + String(macSuffix);
  Serial.println("[BLE] Użyto MAC adresu Bluetooth dla nazwy BLE: " + bleDeviceName);

  BLEDevice::init(bleDeviceName.c_str());
  Serial.println("[BLE] BLEDevice zainicjalizowany.");

  Serial.println("[INFO] Dynamiczny SSID (dla info w BLE): " + dynamicSsid);
  Serial.println("[INFO] Dynamiczne hasło (dla info w BLE): " + dynamicPassword);


  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  Serial.println("[BLE] Serwer BLE utworzony.");

  BLEService *pService = pServer->createService(SERVICE_UUID);
  Serial.println("[BLE] Usługa BLE utworzona z UUID: " + String(SERVICE_UUID));

  // Charakterystyka Current Data (READ, NOTIFY, INDICATE)
  pCurrentDataCharacteristic = pService->createCharacteristic(
                                         CHAR_UUID_CURRENT_DATA,
                                         BLECharacteristic::PROPERTY_READ    |
                                         BLECharacteristic::PROPERTY_NOTIFY |
                                         BLECharacteristic::PROPERTY_INDICATE
                                       );
  pCurrentDataCharacteristic->addDescriptor(new BLE2902());
  Serial.println("[BLE] Charakterystyka CURRENT_DATA utworzona.");

  // Charakterystyka Control Commands (WRITE_NR - Write Without Response)
  pControlCharacteristic = pService->createCharacteristic(
                                         CHAR_UUID_CONTROL,
                                         BLECharacteristic::PROPERTY_WRITE |
                                         BLECharacteristic::PROPERTY_WRITE_NR
                                       );
  pControlCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  Serial.println("[BLE] Charakterystyka CONTROL utworzona.");

  // Charakterystyka Log Data (NOTIFY for chunks, NO onRead)
  pLogDataCharacteristic = pService->createCharacteristic( // Reusing the UUID
                                         CHAR_UUID_LOG_DATA,
                                         BLECharacteristic::PROPERTY_NOTIFY // NOW NOTIFY
                                       );
  pLogDataCharacteristic->addDescriptor(new BLE2902()); // REQUIRED for NOTIFY
  Serial.println("[BLE] Charakterystyka LOG_DATA (teraz NOTIFY) utworzona.");
  // No setValue here, it will be set chunk by chunk by REQUEST_LOGS command


  // Charakterystyka Device Info (READ)
  pDeviceInfoCharacteristic = pService->createCharacteristic(
                                         CHAR_UUID_DEVICE_INFO,
                                         BLECharacteristic::PROPERTY_READ
                                       );
  pDeviceInfoCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  Serial.println("[BLE] Charakterystyka DEVICE_INFO utworzona.");

  pService->start();
  Serial.println("[BLE] Usługa BLE uruchomiona.");

  BLEDevice::setMTU(247);
  Serial.println("[BLE] Requested MTU: 247");

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("[BLE] Reklama BLE rozpoczęta. Urządzenie jest widoczne.");
  Serial.println("--- Setup zakończony ---");
}

// --- Główna pętla programu (Loop) ---
void loop() {
  setLedState();

  // Deklaracja zmiennych na początku funkcji loop
  // float currentSpeedForDisplay = 0.0; // Przeniesiono do zmiennych globalnych, aby nie resetowała się w każdej pętli
  float rawSpeedKmh = 0.0; // Surowa prędkość z GNSS, używana do obliczeń liveMaxSpeed/liveAvgSpeed

  // Odczyt danych z modułu GNSS
  while (gnssSerial.available() > 0) {
    if (gnss.encode(gnssSerial.read())) {
      if (gnss.location.isUpdated() && gnss.location.isValid()) {
        if (gnss.location.age() > MAX_FIX_AGE_MS) {
          Serial.println("[GNSS WARNING] Stare dane GNSS, pomijam. Wiek: " + String(gnss.location.age()) + " ms.");
        } else {
            float currentLat = gnss.location.lat();
            float currentLng = gnss.location.lng();

            rawSpeedKmh = gnss.speed.kmph(); // Surowa prędkość z GNSS od TinyGPSPlus

            currentSpeedForDisplay = rawSpeedKmh; // Używamy prędkości z TinyGPSPlus dla wyświetlania

            // Aktualizuj maks. i średnią prędkość na podstawie surowych danych od TinyGPSPlus
            // liveMaxSpeed zawsze aktualizuj, jeśli nowa prędkość jest większa
            if (rawSpeedKmh > liveMaxSpeed) {
                liveMaxSpeed = rawSpeedKmh;
            }
            // Dodawaj prędkość do sumy tylko jeśli jest powyżej progu dryfu (0.1 km/h) dla średniej
            if (rawSpeedKmh > MIN_SPEED_KMH) {
                liveSumSpeed += rawSpeedKmh;
                liveSpeedCount++;
            }

            if (!hasFirstFixForDistance) {
                // To jest pierwsza ważna poprawka od startu/resetu logowania
                // Inicjalizujemy ostatnie znane współrzędne, ale nie obliczamy dystansu jeszcze
                lastLat = currentLat;
                lastLng = currentLng;
                hasFirstFixForDistance = true;
                Serial.println("[GNSS DEBUG] Pierwsza poprawka GPS do obliczania dystansu zarejestrowana.");
            } else {
                float delta = TinyGPSPlus::distanceBetween(lastLat, lastLng, currentLat, currentLng);

                // Warunki akumulacji dystansu (używamy rawSpeedKmh)
                bool shouldAccumulate = (delta > MIN_DISTANCE_M) &&
                                        (rawSpeedKmh >= MIN_SPEED_KMH) && // Używaj rawSpeedKmh
                                        gnss.satellites.isValid() && (gnss.satellites.value() >= MIN_SATS) &&
                                        gnss.hdop.isValid() && (gnss.hdop.hdop() < MAX_HDOP);

                if (shouldAccumulate) {
                    distance_km += delta / 1000.0; // distance_km is actually in KM here, not meters. But the variable name suggests KM so it's consistent.
                } else {
                    // Dodano logowanie powodu, dla którego dystans NIE jest akumulowany
                    // (może być przydatne do dalszej diagnostyki działania GPS)
                    // Serial.print("[GNSS DEBUG] Dystans NIE akumulowany. Powód: ");
                    // if (!(delta > MIN_DISTANCE_M)) Serial.print("Delta za mała | ");
                    // if (!(rawSpeedKmh >= MIN_SPEED_KMH)) Serial.print("Prędkość za niska | ");
                    // if (!gnss.satellites.isValid()) Serial.print("Satelity nieważne | ");
                    // else if (!(gnss.satellites.value() >= MIN_SATS)) Serial.print("Za mało satelitów | ");
                    // if (!gnss.hdop.isValid()) Serial.print("HDOP nieważny | ");
                    // else if (!(gnss.hdop.hdop() < MAX_HDOP)) Serial.print("HDOP za wysoki | ");
                    // Serial.println();
                }
                // Zawsze aktualizuj ostatnie współrzędne PO obliczeniu delty, aby były gotowe na następny punkt
                lastLat = currentLat;
                lastLng = currentLng;
            }
            if (loggingActive) {
                // Zapisuj surową prędkość do pliku logu
                // Note: distance_km is in KM here, but addDataToBuffer expects meters.
                // Let's adjust addDataToBuffer or ensure consistency.
                // Given the header ['Distance (m)'] in CSV, it should be meters.
                // So, let's pass distance_km * 1000.0 to addDataToBuffer
                addDataToBuffer(millis() / 1000, rawSpeedKmh, distance_km * 1000.0, currentLat, currentLng);
            }
        }
      }
    }
  }

  // --- Okresowy odczyt napięcia baterii ---
  if (millis() - lastBatteryReadMillis > BATTERY_READ_INTERVAL_MS) {
    readBatteryVoltage();
    lastBatteryReadMillis = millis();
  }

  // *** Wysyłanie aktualnych danych przez BLE (Notify) - TERAZ CYKLICZNE ***
  if (deviceConnected && pCurrentDataCharacteristic != NULL && (millis() - lastBleNotifyMillis > currentBleNotifyInterval)) {
      lastBleNotifyMillis = millis();

      float liveAvgSpeed = (liveSpeedCount > 0) ? liveSumSpeed / liveSpeedCount : 0.0;

      int gnssQualityLevel = 0;
      float hdop = gnss.hdop.isValid() ? gnss.hdop.hdop() : 99.9;
      int sats = gnss.satellites.isValid() ? gnss.satellites.value() : 0;

      if (gnss.hdop.isValid() && gnss.satellites.isValid()) {
          float hdopVal = gnss.hdop.hdop();
          int satsVal = gnss.satellites.value();
          if (satsVal >= 12 && hdopVal < 1.0) gnssQualityLevel = 5;
          else if (satsVal >= 9 && hdopVal < 1.8) gnssQualityLevel = 4;
          else if (satsVal >= 7 && hdopVal < 2.5) gnssQualityLevel = 3;
          else if (satsVal >= 5 && hdopVal < 5.0) gnssQualityLevel = 2;
          else if (satsVal > 0) gnssQualityLevel = 1;
      }

      String json = "{";
      json += "\"latitude\":" + (gnss.location.isValid() ? String(gnss.location.lat(), 6) : "null") + ",";
      json += "\"longitude\":" + (gnss.location.isValid() ? String(gnss.location.lng(), 6) : "null") + ",";
      json += "\"altitude\":" + (gnss.altitude.isValid() ? String(gnss.altitude.meters()) : "0") + ",";
      json += "\"satellites\":" + String(sats) + ",";
      json += "\"hdop\":" + (gnss.hdop.isValid() ? String(hdop, 2) : "0") + ",";
      json += "\"currentSpeed\":" + String(currentSpeedForDisplay, 2) + ",";
      json += "\"maxSpeed\":" + String(liveMaxSpeed, 2) + ",";
      json += "\"avgSpeed\":" + String(liveAvgSpeed, 2) + ",";
      // POPRAWKA TUTAJ: Wysyłaj dystans jako liczbę (float), nie string
      json += "\"distance\":" + String(distance_km * 1000.0, 3) + ","; // Wysyłamy dystans w METRACH!
      json += "\"gpsQualityLevel\":" + String(gnssQualityLevel) + ",";
      json += "\"battery\":" + String(batteryPercentage, 0) + ",";
      json += String("\"isLoggingActive\":") + (loggingActive ? "true" : "false");
      json += "}";

      pCurrentDataCharacteristic->setValue(json.c_str());
      pCurrentDataCharacteristic->notify();
  }

  // Zapis danych do pliku w regularnych odstępach czasu, jeśli logowanie jest aktywne
  if (loggingActive && measurementDataBuffer.length() > 0 && (millis() - lastFileWriteMillis > FILE_WRITE_INTERVAL_MS)) {
      writeBufferToFile();
      lastFileWriteMillis = millis();
  }

  // --- Obsługa wysyłania logów przez notify (pojedyncze obiekty JSON) ---
  if (isLogTransferActive && deviceConnected && pLogDataCharacteristic != NULL && logFile) {
      // This delay is CRITICAL for large file transfers. A slightly longer delay
      // increases stability at the cost of a slower transfer.
      delay(10); // Zwiększono z 5ms do 10ms dla większej stabilności

      if (logFile.available()) {
          String line = logFile.readStringUntil('\n');
          line.trim();

          if (line.length() > 0) {
              int firstComma = line.indexOf(',');
              int secondComma = line.indexOf(',', firstComma + 1);
              int thirdComma = line.indexOf(',', secondComma + 1);
              int fourthComma = line.indexOf(',', thirdComma + 1);

              if (firstComma != -1 && secondComma != -1 && thirdComma != -1 && fourthComma != -1) {
                  // Format as a single JSON object
                  String jsonLine = "{\"timestamp\":" + line.substring(0, firstComma) +
                                    ",\"speed\":" + line.substring(firstComma + 1, secondComma) +
                                    ",\"distance\":" + line.substring(secondComma + 1, thirdComma) + // This is already meters in log.csv from addDataToBuffer
                                    ",\"latitude\":" + line.substring(thirdComma + 1, fourthComma) +
                                    ",\"longitude\":" + line.substring(fourthComma + 1) + "}";

                  // Ensure the JSON object fits within a single BLE packet size
                  if (jsonLine.length() > MAX_BLE_PACKET_SIZE) {
                      Serial.print("[BLE LOG TRANSFER ERROR] JSON object too large for single packet (");
                      Serial.print(jsonLine.length());
                      Serial.print(" bytes): ");
                      Serial.println(jsonLine.substring(0, 50) + "..."); // Print a truncated version
                      // You might need to handle this by splitting the JSON, but for GPS data,
                      // a single line should typically fit. If not, consider reducing precision or data points.
                  }

                  pLogDataCharacteristic->setValue(jsonLine.c_str());
                  pLogDataCharacteristic->notify();
                  currentLogTransferIndex++; // Increment line counter

                  Serial.print("[BLE LOG TRANSFER] Wysłano obiekt JSON. Linia ");
                  Serial.print(currentLogTransferIndex);
                  Serial.print(" z ");
                  Serial.print(_totalLinesInLogFile);
                  Serial.print(", Rozmiar: ");
                  Serial.print(jsonLine.length());
                  Serial.println(" bajtów.");
              } else {
                  Serial.println("[BLE LOG TRANSFER WARNING] Pominięto linię (błąd formatu CSV): " + line);
              }
          }
      } else {
          // Wszystkie linie zostały odczytane z pliku.
          // Najpierw wyślij znacznik końca do aplikacji. To musi być zrobione przed zmianą stanu.
          Serial.println("[BLE LOG TRANSFER] Transfer logów zakończony. Wysyłam znacznik końca.");
          pLogDataCharacteristic->setValue("END_LOG_TRANSFER");
          pLogDataCharacteristic->notify();
          delay(100); // Daj chwilę na wysłanie powiadomienia przed czyszczeniem.

          // Po zakończeniu transferu, wracamy do trybu oszczędzania energii
          Serial.println("[POWER_CONFIG] Transfer zakończony, powrót do 80 MHz.");
          setCpuFrequencyMhz(80);

          // Teraz wyczyść stan.
          isLogTransferActive = false;
          logFile.close(); // Close the file after full transfer
          currentLogTransferIndex = 0;
          _totalLinesInLogFile = 0; // Reset total lines after transfer
      }
  }
}
