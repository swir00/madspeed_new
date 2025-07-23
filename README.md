## **Opis i funkcje aplikacji MadSpeed**

Aplikacja "MadSpeed" to kompleksowe narzędzie mobilne zaprojektowane do monitorowania i analizowania aktywności Twojego psa, ze szczególnym uwzględnieniem danych dotyczących prędkości i treningów. Aplikacja łączy się z zewnętrznymi urządzeniami Bluetooth Low Energy (BLE) w celu zbierania precyzyjnych danych, a także oferuje rozbudowane funkcje zarządzania profilami psów i historią treningów.

### **Główne funkcje aplikacji:**

1. **Łączność Bluetooth Low Energy (BLE)**  
   * Aplikacja skanuje i łączy się z urządzeniami MadSpeed (BLE), aby w czasie rzeczywistym odbierać dane dotyczące prędkości, dystansu i statusu logowania.  
   * Wyświetla aktualny status połączenia Bluetooth (włączony/wyłączony) i pozwala na szybkie włączenie Bluetooth w systemie operacyjnym.  
2. **Tryby działania:**  
   * **Tryb Speed Master:**  
     * Umożliwia bieżące monitorowanie maksymalnej, średniej i chwilowej prędkości.  
     * Idealny do szybkich pomiarów prędkości bez konieczności zapisywania pełnego treningu.  
     * Oferuje opcję resetowania danych na urządzeniu.  
   * **Tryb Treningu:**  
     * Pozwala na rozpoczęcie i zakończenie sesji logowania danych z urządzenia BLE.  
     * Zbiera dane o maksymalnej prędkości, całkowitym dystansie, średniej prędkości i czasie trwania treningu.  
     * **Powiązanie z profilem psa**: Każdy trening może być przypisany do konkretnego profilu psa, co umożliwia spersonalizowaną analizę.  
     * **Pobieranie lokalizacji startowej**: Aplikacja pobiera lokalizację GPS na początku treningu, aby później móc wyświetlić dane pogodowe dla tego miejsca.  
     * **Wykres danych logowania**: Po zakończeniu treningu generowany jest wykres wizualizujący prędkość i dystans w czasie.  
     * **Zapisywanie sesji**: Użytkownik może nazwać i zapisać sesję treningową do późniejszej analizy w historii.  
     * **Resetowanie danych**: Możliwość zresetowania danych na podłączonym urządzeniu.  
3. **Zarządzanie profilami psów:**  
   * **Tworzenie i edycja profili**: Dodawaj i edytuj szczegółowe profile dla każdego psa, w tym:  
     * Imię  
     * Rasa (z predefiniowaną listą chartów lub opcją "Inne")  
     * Data urodzenia (do obliczania wieku)  
     * Płeć  
     * Aktualna waga  
     * Poziom aktywności (niski, umiarkowany, wysoki)  
     * **Zdjęcie**: Możliwość dodania zdjęcia psa z galerii lub aparatu.  
     * **Cele fitness**: Ustawianie docelowej wagi, dziennego celu dystansu i dziennego celu czasu aktywności.  
   * **Lista profili**: Przeglądaj wszystkie dodane profile psów.  
   * **Usuwanie profili**: Bezpieczne usuwanie profili psów.  
4. **Szczegóły profilu psa:**  
   * Dedykowany ekran do przeglądania szczegółowych informacji o wybranym psie.  
   * **Historia wagi**: Wyświetla listę wpisów wagi i wizualizuje je na wykresie liniowym, co pozwala śledzić zmiany wagi w czasie. Możliwość dodawania i usuwania wpisów wagi.  
   * **Historia treningów**: Pokazuje wszystkie sesje treningowe przypisane do danego psa.  
     * Dla każdej sesji wyświetla: nazwę, datę, dystans, średnią i maksymalną prędkość, czas trwania oraz **szacunkowe spalone kalorie**, uwzględniające wagę psa, poziom aktywności, prędkość treningu, a nawet **warunki pogodowe** (temperatura, wiatr, wilgotność) w miejscu rozpoczęcia treningu.  
     * **Podgląd treningu**: Kliknięcie na sesję treningową otwiera szczegółowy podgląd z wykresem prędkości/dystansu, danymi pogodowymi i opcją wyświetlenia trasy na mapie.  
5. **Historia wyników:**  
   * Dwa widoki (zakładki) do przeglądania zapisanych sesji: "Speed Master" i "Treningi".  
   * Wyświetla kluczowe statystyki dla każdej sesji.  
   * **Eksport danych**: Możliwość eksportowania danych logów treningowych do pliku CSV, który można udostępnić.  
   * **Usuwanie sesji**: Możliwość usuwania pojedynczych sesji z historii.  
6. **Informacje o urządzeniu:**  
   * Ekran wyświetlający szczegółowe informacje o podłączonym urządzeniu MadSpeed.

### **Technologie wykorzystane w aplikacji:**

* **Flutter**: Framework do budowy natywnych aplikacji mobilnych dla Androida i iOS z jednej bazy kodu.  
* **Bluetooth Low Energy (BLE)**: Do komunikacji z zewnętrznymi sensorami MadSpeed.  
* **Provider**: Do zarządzania stanem aplikacji.  
* **SQLite (za pomocą pakietu sqflite)**: Do lokalnego przechowywania danych profili psów i wpisów wagi.  
* **SharedPreferences**: Do przechowywania danych sesji treningowych i Speed Mastera.  
* **image\_picker**: Do wyboru zdjęć z galerii lub aparatu.  
* **intl**: Do formatowania dat i czasu.  
* **fl\_chart**: Do generowania interaktywnych wykresów wagi i prędkości/dystansu.  
* **geolocator**: Do pobierania danych lokalizacyjnych (GPS).  
* **google\_maps\_flutter**: Do wyświetlania tras treningowych na mapie.  
* **OpenWeatherMap API (http)**: Do pobierania danych pogodowych dla lokalizacji startowej treningów.  
* **path\_provider i csv**: Do eksportowania danych do formatu CSV.  
* **share\_plus**: Do udostępniania wyeksportowanych plików CSV.

Aplikacja MadSpeed to wszechstronne narzędzie dla właścicieli psów, którzy chcą aktywnie monitorować i optymalizować aktywność fizyczną swoich pupili, zapewniając im zdrowie i kondycję.