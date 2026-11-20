# Blok 10 - konfiguracja przygotowana do wdrożenia

Stan na 20.11.2026. Pliki w tej gałęzi przygotowują monitoring. Weryfikacja kosztów, wybór odbiorców, instalacja w Azure i zebranie dowodów pozostają do wykonania.

## E1 - budżet

Szablon resources.bicep tworzy budżet dla rg-gearpass. Domyślna kwota 30 dotyczy waluty rozliczeniowej subskrypcji. Przed wdrożeniem należy potwierdzić walutę i aktualne saldo. Progi 50, 80 i 100 procent wysyłają wiadomości na zweryfikowaną listę contactEmails zawierającą PM-a i członków zespołu. Budżet rozpoczyna się pierwszego dnia bieżącego miesiąca i resetuje co miesiąc. Obejmuje całą grupę rg-gearpass.

Alert budżetowy jest powiadomieniem. Koszty są aktualizowane z opóźnieniem, a alert nie zatrzymuje maszyn. Utrzymanie aplikacji do 6 grudnia wymaga sprawdzania aktualnego salda i kosztów pozostałych zasobów subskrypcji.

## E2 - gotowość aplikacji

GET /health wykonuje SELECT 1 w PostgreSQL i zwraca 200 z {"status":"UP","database":"UP"}. Niedostępna baza daje 503 i status DOWN. Brak konfiguracji PostgreSQL daje 503 i NOT_CONFIGURED. Dotychczasowy /api/health zachowuje format wykorzystywany przez frontend oraz CI/CD.

Zmiana wymaga publikacji backendu na vm-gearpass-app i reguły Caddy przekazującej /health do 10.79.0.68:8000. Na vm-gearpass-web trzeba też uruchomić sondę co minutę, np. timer systemd z curl --fail --max-time 8 http://10.79.0.68:8000/health. Po wdrożeniu należy sprawdzić publiczny adres oraz zachowanie po błędzie bazy w kontrolowanym teście.

## E3 - centralne logi

Wybrany wariant korzysta z Azure Monitor Agent na istniejącej maszynie Web. App i Data przekazują Syslog po prywatnym TCP 5514 do Web. NSG dopuszcza ten ruch tylko między wskazanymi prywatnymi adresami. DCR zbiera facility local0 (FastAPI), local1 (PostgreSQL) i local2 (CPU/RAM). Dane trafiają do tabeli Syslog w Log Analytics.

Przed uruchomieniem szablonu trzeba nadać istniejącej maszynie Web systemową tożsamość zarządzaną. Agent wymaga dostępnego wyjścia HTTPS do Azure Monitor i Azure Resource Manager oraz działającego DNS. Działający Web ma publiczny adres i wyjściowe TCP 443. App i Data zachowują prywatne adresy, a ich telemetria wychodzi do Web.

Na każdej VM należy sprawdzić obecność rsyslog, skopiować configure-vm.sh oraz emit-metrics.py i uruchomić skrypt z rolą web, app lub data jako root. Należy najpierw wdrożyć zmiany backendu. Skrypt ustawia logi systemd, przekazywanie Syslog i próbki CPU/RAM co 60 sekund. Na Data włącza logi połączeń PostgreSQL i zapis lokalny stderr. Zapytania SQL pozostają poza strumieniem logów.

Kod API zapisuje czas obsługi, kod HTTP i wzorzec ścieżki. Pomija query string, nagłówki i treść żądania. Do oceny błędów służy status_code. Czas duration_ms dotyczy obsługi w API.

## E4 - dashboard

Szablon tworzy współdzielony Azure Workbook „GearPass - CPU, RAM i API”. CPU i RAM dla każdej maszyny pochodzą z próbek Syslog co minutę. Pozostałe wykresy pokazują średni i p95 czas obsługi API oraz liczbę odpowiedzi według kodów. Tabela pokazuje logi FastAPI i PostgreSQL.

Po pierwszym wdrożeniu należy zaczekać na ingestę, wygenerować żądania testowe i sprawdzić każdy wykres. W portalu należy włączyć odświeżanie co minutę. Puste wykresy wymagają sprawdzenia timerów, rsyslog, połączenia z agentem i DCR.

## Kontrola kosztów

Workspace używa PerGB2018, retencji 30 dni i dziennego limitu 0,05 GB. Faktyczna opłata zależy od stawki subskrypcji i ingestii. Limit jest mechanizmem ograniczenia wolumenu i może zostać przekroczony przez opóźnione zatrzymanie. Po osiągnięciu limitu dane mogą przestać napływać do kolejnego resetu.

Kolektor używa istniejącej maszyny Web. Plan zakłada pozostawienie trzech maszyn Standard_B1s i jednego publicznego IP. Przed wdrożeniem należy sprawdzić wolną pamięć Web i zapas kredytów do 6 grudnia. Należy ocenić dobową ingestę po uruchomieniu oraz koszt całej subskrypcji.

## Kolejność wdrożenia i dowody

1. Sprawdzić aktualne saldo, walutę, koszty i adresy odbiorców.
2. Zweryfikować szablon Bicep. Włączyć tożsamość Web, wdrożyć zasoby monitoringu i sprawdzić reguły NSG.
3. Zaktualizować backend. Skopiować skrypty na VM i sprawdzić ich wykonanie.
4. Sprawdzić GET /health, dane w Syslog i wszystkie wykresy workbooka.
5. Zebrać zrzuty alertów, JSON z /health, logów, wykresów i sekcji README. W PDF opisać faktycznie wykonany wkład przy E1-E5.

Dokumentacja Microsoft
- https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets
- https://learn.microsoft.com/azure/azure-monitor/vm/data-collection-syslog
- https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-network-configuration
- https://learn.microsoft.com/azure/azure-monitor/logs/daily-cap
