// --- Konieczne zdefiniowanie aliasów pinów dla Seeed Studio XIAO ESP32S3 ---
// WERYFIKACJA PINÓW NA PODSTAWIE DOSTARCZONEGO SCHEMATU:
// LED_BUILTIN jest poprawnie zdefiniowany dla tej płytki
// Potwierdzono, że na Seeed Studio XIAO ESP32S3 dioda LED jest active-LOW
#define GNSS_RX_PIN 44             // D7 na pinoucie (GPIO44)
#define GNSS_TX_PIN 43             // D6 na pinoucie (GPIO43)
#define BATTERY_PIN 2              // A1 na pinoucie (GPIO2)

// Prototypy funkcji
void writeBufferToFile();
void readBatteryVoltage(); 
void sendPMTKCommand(const String& command); 

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h> // Do deskryptora Client Characteristic Configuration (dla Notify)
#include <TinyGPSPlus.h>
#include <HardwareSerial.h> // Wymagane dla HardwareSerial(x)

// Nagłówki do pobierania MAC adresu Wi-Fi (do nazwy BLE i SSID AP)
#include "esp_system.h"    // Dla esp_chip_info() i esp_random()
#include "esp_wifi.h"      // Dla esp_wifi_get_mac()
#include <SPIFFS.h>        // Do obsługi systemu plików

// --- Parametry precyzji GNSS ---
#define MIN_DISTANCE_M    0.05  // ZMNIEJSZONO: Min. odległość do dodania do dystansu (w metrach)
#define MIN_SPEED_KMH     0.5   // Min. prędkość do uznania za ruch (w km/h)
#define MIN_SATS          7     // Min. liczba satelitów dla dobrej precyzji
#define MAX_HDOP          2.5   // Maks. HDOP (Horizontal Dilution of Precision) dla dobrej precyzji
#define MAX_FIX_AGE_MS    1500  // Maks. wiek poprawki GNSS (w milisekundach), po którym dane są uznawane za stare

const char* DATA_FILE = "/log.csv";    // Nazwa pliku do logowania danych

// --- UUID dla usług i charakterystyk BLE ---
// UWAGA: Te UUID są wygenerowane losowo. Upewnij się, że używasz TYCH SAMYCH w aplikacji Flutter!
#define SERVICE_UUID              "A2A00000-B1B1-C2C2-D3D3-E4E4E4E4E4E4" // Główna usługa MadSpeed
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
float maxSpeed = 0;
float sumSpeed = 0;
int speedCount = 0;
float distance_km = 0;
float lastLat = 0.0;
float lastLng = 0.0;
String measurementDataBuffer = ""; // Bufor na dane do zapisu do pliku
unsigned long lastFileWriteMillis = 0;
const unsigned long FILE_WRITE_INTERVAL_MS = 5000; // Interwał zapisu danych do pliku (5 sekund)
bool loggingActive = false; // Status logowania (czy dane są zapisywane do pliku)

// --- Zmienne dla LED ---
unsigned long lastBlinkMillis = 0;
const unsigned long BLINK_INTERVAL_MS = 250; // Interwał mrugania diody (250 ms)

// --- Zmienne dla cyklicznych powiadomień BLE ---
unsigned long lastBleNotifyMillis = 0;
// Zmienna, którą będziemy zmieniać w zależności od trybu (Speed Master / Trening)
unsigned long currentBleNotifyInterval = 1000; // Domyślnie 1 sekunda (1000 ms)

// --- Zmienne SSID/Password (ustawione na stałe lub puste, jeśli nie używasz WiFi) ---
String dynamicSsid; // Dedykowane dla przyszłych funkcji WiFi/WEB
String dynamicPassword; // Dedykowane dla przyszłych funkcji WiFi/WEB

// --- Zmienne dla odczytu baterii ---
float currentBatteryVoltage = 0.0; // Przechowuje ostatnie odczytane napięcie baterii
unsigned long lastBatteryReadMillis = 0;
const unsigned long BATTERY_READ_INTERVAL_MS = 15000; // Odczytuj baterię co 15 sekund

// --- Zmienne do transferu logów przez NOTIFY ---
const int MAX_BLE_PACKET_SIZE = 240; // Max size for BLE MTU (247 bytes - 7 bytes GATT header)
String fullLogDataToTransfer = ""; // Bufor na pełne dane logów do wysłania
int currentLogTransferIndex = 0;
bool isLogTransferActive = false; // Flaga kontrolująca aktywny transfer logów


// --- Klasy Callbacks dla BLE ---

// Klasa do obsługi zdarzeń serwera BLE (połączenie/rozłączenie)
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("[BLE] Urządzenie BLE połączone.");
      // Możesz tutaj wyłączyć reklamowanie, jeśli chcesz tylko jedno połączenie naraz
      // BLEDevice::getAdvertising()->stop();
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("[BLE] Urządzenie BLE rozłączone. Rozpoczynanie ponownej reklamy...");
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
          maxSpeed = 0; sumSpeed = 0; speedCount = 0; distance_km = 0; lastLat = 0.0; lastLng = 0.0;
          measurementDataBuffer = ""; // Wyczyść bufor
          lastFileWriteMillis = millis(); 
          isLogTransferActive = false; // Zatrzymaj ewentualny transfer logów
          fullLogDataToTransfer = ""; // Wyczyść bufor transferu
          Serial.println("[LOG] Logowanie ROZPOCZĘTE.");
        } else if (command == "STOP_LOG") {
          loggingActive = false;
          writeBufferToFile(); // Zapisz pozostałe dane, które są w buforze
          Serial.println("[LOG] Logowanie ZATRZYMANE i dane zapisane.");
          // Po zatrzymaniu logowania, NIE rozpoczynamy automatycznie transferu.
          // Transfer zostanie zainicjowany przez komendę REQUEST_LOGS z Fluttera.
        } else if (command == "RESET") {
          loggingActive = false;
          maxSpeed = 0; sumSpeed = 0; speedCount = 0; distance_km = 0; lastLat = 0.0; lastLng = 0.0;
          measurementDataBuffer = ""; 
          if (SPIFFS.exists(DATA_FILE)) {
            SPIFFS.remove(DATA_FILE); // Usuń plik logowania
            Serial.println("[SPIFFS] Plik logowania usunięty.");
          }
          isLogTransferActive = false; // Zatrzymaj ewentualny transfer logów
          fullLogDataToTransfer = ""; // Wyczyść bufor transferu
          Serial.println("[DATA] Dane zresetowane.");
        } else if (command == "REQUEST_LOGS") { // NOWA KOMENDA DLA FLUTTERA
          Serial.println("[BLE] Otrzymano żądanie transferu logów.");
          fullLogDataToTransfer = "["; // Rozpocznij budowanie pełnego JSON-a
          bool hasData = false; 
          if (SPIFFS.exists(DATA_FILE)) {
              File file = SPIFFS.open(DATA_FILE, FILE_READ);
              if (file) {
                  while (file.available()) {
                      String line = file.readStringUntil('\n'); line.trim();
                      if (line.length() > 0) {
                          int firstComma = line.indexOf(',');
                          int secondComma = line.indexOf(',', firstComma + 1);
                          if (firstComma != -1 && secondComma != -1) { 
                              if (hasData) fullLogDataToTransfer += ","; 
                              fullLogDataToTransfer += "{\"timestamp\":" + line.substring(0, firstComma) + 
                                              ",\"speed\":" + line.substring(firstComma + 1, secondComma) + 
                                              ",\"distance\":" + line.substring(secondComma + 1) + "}"; // Odległość w metrach
                              hasData = true;
                          }
                      }
                  }
                  file.close();
              }
          }
          fullLogDataToTransfer += "]";
          currentLogTransferIndex = 0; // Zresetuj indeks chunk'a
          isLogTransferActive = true; // Aktywuj transfer logów
          Serial.print("[BLE LOG TRANSFER] Przygotowano pełne dane logów do transferu. Rozmiar: ");
          Serial.print(fullLogDataToTransfer.length());
          Serial.println(" bajtów. Rozpoczynanie transferu...");
          // Jeśli jest pusty, wysyłamy pusty []
          if (fullLogDataToTransfer.length() <= 2) { // 2 znaki to "[]"
              pLogDataCharacteristic->setValue("[]");
              pLogDataCharacteristic->notify();
              Serial.println("[BLE LOG TRANSFER] Wysłano pustą listę logów.");
              isLogTransferActive = false; // Zakończ transfer
          }
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
            readBatteryVoltage(); 
            String infoJson = "{\"ssid\":\"" + dynamicSsid + "\",\"password\":\"" + dynamicPassword + "\",\"isLoggingActive\":" + (loggingActive ? "true" : "false") + ",\"battery\":" + String(currentBatteryVoltage, 2) + "}";
            pCharacteristic->setValue(infoJson.c_str());
            Serial.println("[BLE] Wysłano informacje o urządzeniu: " + infoJson);
        }
        // CHAR_UUID_LOG_DATA nie ma już onRead, bo używa notify
    }
};

// --- Funkcje pomocnicze ---

// Sterowanie diodą LED (dla Seeed Studio XIAO ESP32S3, potwierdzone active-LOW)
void setLedState() {
  if (loggingActive) {
    // Tryb logowania: dioda miga
    if (millis() - lastBlinkMillis > BLINK_INTERVAL_MS) {
      // Przełączanie stanu dla active-LOW
      digitalWrite(LED_BUILTIN, digitalRead(LED_BUILTIN) == HIGH ? LOW : HIGH);
      lastBlinkMillis = millis();
    }
  } else {
    // Urządzenie włączone (bez logowania): dioda świeci światłem ciągłym
    // Aby dioda świeciła w trybie active-LOW, ustawiamy pin na LOW.
    digitalWrite(LED_BUILTIN, LOW); 
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
void addDataToBuffer(unsigned long timestamp, float speed, float distance_meters) {
  // Format: timestamp_s,speed_kmh,distance_m
  measurementDataBuffer += String(timestamp) + "," + String(speed, 2) + "," + String((int)round(distance_meters)) + "\n";
}

// Zapis bufora do pliku SPIFFS
void writeBufferToFile() {
  if (measurementDataBuffer.length() == 0) {
    Serial.println("[SPIFFS] Bufor danych pusty, nic do zapisu.");
    return; // Nic do zapisu
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

// Funkcja do odczytu napięcia baterii
void readBatteryVoltage() {
  float rawADC_sum = 0; 
  int numReadings = 100; 
  for (int i = 0; i < numReadings; i++) {
      rawADC_sum += analogRead(BATTERY_PIN);
      delayMicroseconds(10); 
  }
  float rawADC = rawADC_sum / numReadings;
  currentBatteryVoltage = rawADC * (3.3f / 4095.0f) * 2.0f; 
  Serial.print("[BATT] Odczyt baterii: "); Serial.print(currentBatteryVoltage, 2); Serial.println("V");
}


// --- Konfiguracja (Setup) ---
void setup() {
  Serial.begin(115200); 
  Serial.println("\n--- Start MadSpeed Device ---");

  pinMode(LED_BUILTIN, OUTPUT);  
  digitalWrite(LED_BUILTIN, LOW); 
  Serial.println("[LED] Dioda LED włączona (stan początkowy).");

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

  uint8_t macWifi[6];
  esp_wifi_get_mac(WIFI_IF_STA, macWifi); 
  char macSuffix[7];
  snprintf(macSuffix, sizeof(macSuffix), "%02X%02X%02X", macWifi[3], macWifi[4], macWifi[5]);
  String bleDeviceName = "MadSpeed_" + String(macSuffix);
  Serial.println("[BLE] Użyto MAC WiFi dla nazwy BLE: " + bleDeviceName);

  BLEDevice::init(bleDeviceName.c_str()); 
  Serial.println("[BLE] BLEDevice zainicjalizowany.");

  uint8_t macWifiAp[6];
  esp_wifi_get_mac(WIFI_IF_AP, macWifiAp);  
  char macSuffixWifiAp[7];
  snprintf(macSuffixWifiAp, sizeof(macSuffixWifiAp), "%02X%02X%02X", macWifiAp[3], macWifiAp[4], macWifiAp[5]);
  dynamicSsid = "madspeed_AP_" + String(macSuffixWifiAp);
  dynamicPassword = "madweb_" + String(macSuffixWifiAp);
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

  // Odczyt danych z modułu GNSS
  while (gnssSerial.available() > 0) {
    if (gnss.encode(gnssSerial.read())) { 
      if (gnss.location.isUpdated() && gnss.location.isValid()) {
        if (gnss.location.age() > MAX_FIX_AGE_MS) {
          Serial.println("[GNSS WARNING] Stare dane GNSS, pomijam. Wiek: " + String(gnss.location.age()) + " ms.");
        } else {
            float currentSpeedKmh = gnss.speed.kmph();
            if (currentSpeedKmh < 0.3) currentSpeedKmh = 0; 

            if (currentSpeedKmh > maxSpeed) maxSpeed = currentSpeedKmh;
            sumSpeed += currentSpeedKmh;
            speedCount++;

            float delta = 0; 
            if (lastLat != 0.0 || lastLng != 0.0) {
              delta = TinyGPSPlus::distanceBetween(lastLat, lastLng, gnss.location.lat(), gnss.location.lng());
            }
            // Serial.print("[GNSS DEBUG] Obliczona Delta: "); Serial.print(delta, 6); Serial.println(" m"); // Odkomentuj tylko do debugowania

            if (delta > MIN_DISTANCE_M && currentSpeedKmh >= MIN_SPEED_KMH && gnss.satellites.isValid() && gnss.satellites.value() >= MIN_SATS && gnss.hdop.isValid() && gnss.hdop.hdop() < MAX_HDOP) {
              distance_km += delta / 1000.0; 
              // Serial.print("[GNSS DEBUG] Dystans akumulowany. Delta: "); Serial.print(delta, 3); Serial.print(" m, Akumulowany dystans: "); Serial.print(distance_km, 3); Serial.println(" km"); // Odkomentuj tylko do debugowania
            } else {
              // Serial.print("[GNSS DEBUG] Dystans NIE akumulowany. Delta: "); Serial.print(delta, 3); Serial.print(" m (Min: "); Serial.print(MIN_DISTANCE_M, 2);
              // Serial.print("), Prędkość: "); Serial.print(currentSpeedKmh, 2); Serial.print(" (Min: "); Serial.print(MIN_SPEED_KMH, 2);
              // Serial.print("), Sat: "); Serial.print(gnss.satellites.isValid() ? gnss.satellites.value() : 0); Serial.print(" (Min: "); Serial.print(MIN_SATS);
              // Serial.print("), HDOP: "); Serial.print(gnss.hdop.isValid() ? gnss.hdop.hdop() : 99.9, 2); Serial.print(" (Max: "); Serial.print(MAX_HDOP, 2); Serial.println(")"); // Odkomentuj tylko do debugowania
            }

            lastLat = gnss.location.lat();
            lastLng = gnss.location.lng();

            if (loggingActive) {
              addDataToBuffer(millis() / 1000, currentSpeedKmh, distance_km * 1000); 
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

      float currentSpeedKmh = gnss.speed.isValid() ? gnss.speed.kmph() : 0.0;
      if (currentSpeedKmh < 0.3) currentSpeedKmh = 0; 

      float avgSpeed = speedCount > 0 ? sumSpeed / speedCount : 0.0;

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
      json += "\"currentSpeed\":" + String(currentSpeedKmh, 2) + ",";
      json += "\"maxSpeed\":" + String(maxSpeed, 2) + ",";
      json += "\"avgSpeed\":" + String(avgSpeed, 2) + ",";
      json += "\"distance\":" + String(distance_km, 3) + ","; 
      json += "\"gpsQualityLevel\":" + String(gnssQualityLevel) + ",";
      json += "\"battery\":" + String(currentBatteryVoltage, 2) + ","; 
      json += String("\"isLoggingActive\":") + (loggingActive ? "true" : "false");
      json += "}";

      pCurrentDataCharacteristic->setValue(json.c_str()); 
      pCurrentDataCharacteristic->notify(); 
      // Serial.println("[BLE] Wysłano dane BLE: " + json); // Odkomentuj dla szczegółowego debugowania BLE
  }

  // Zapis danych do pliku w regularnych odstępach czasu, jeśli logowanie jest aktywne
  if (loggingActive && measurementDataBuffer.length() > 0 && (millis() - lastFileWriteMillis > FILE_WRITE_INTERVAL_MS)) {
      writeBufferToFile();
      lastFileWriteMillis = millis();
  }

  // --- Obsługa wysyłania logów przez notify (fragmenty) ---
  // Wysyłaj fragmenty tylko jeśli fullLogDataToTransfer jest niepusty, jest połączenie BLE
  // i transfer jest aktywny.
  if (isLogTransferActive && deviceConnected && pLogDataCharacteristic != NULL) { // pLogDataCharacteristic is now the notify characteristic
    // Sprawdź, czy są jeszcze fragmenty do wysłania
    if (currentLogTransferIndex * MAX_BLE_PACKET_SIZE < fullLogDataToTransfer.length()) {
      int startIndex = currentLogTransferIndex * MAX_BLE_PACKET_SIZE;
      int endIndex = startIndex + MAX_BLE_PACKET_SIZE;
      if (endIndex > fullLogDataToTransfer.length()) {
        endIndex = fullLogDataToTransfer.length();
      }
      String chunk = fullLogDataToTransfer.substring(startIndex, endIndex);

      pLogDataCharacteristic->setValue(chunk.c_str()); 
      pLogDataCharacteristic->notify();

      Serial.print("[BLE LOG TRANSFER] Wysłano chunk ");
      Serial.print(currentLogTransferIndex + 1);
      Serial.print("/");
      Serial.print((fullLogDataToTransfer.length() + MAX_BLE_PACKET_SIZE - 1) / MAX_BLE_PACKET_SIZE);
      Serial.print(", Rozmiar: ");
      Serial.print(chunk.length());
      Serial.println(" bajtów.");

      currentLogTransferIndex++;
    } else {
      // Wszystkie fragmenty wysłane, zakończ transfer
      isLogTransferActive = false;
      fullLogDataToTransfer = ""; // Wyczyść bufor po zakończeniu transferu
      currentLogTransferIndex = 0;
      // Możesz wysłać pusty pakiet lub specjalną flagę zakończenia, jeśli potrzebujesz w Flutterze
      pLogDataCharacteristic->setValue("END"); // Sygnał zakończenia transferu
      pLogDataCharacteristic->notify();
      Serial.println("[BLE LOG TRANSFER] Zakończono transfer logów.");
    }
  }

  // Małe opóźnienie, aby uniknąć zapętlania i pozwolić na inne zadania
  delay(1); 
}
