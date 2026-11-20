# Blok 10 - wdrożenie i weryfikacja

Wdrożenie zweryfikowano 20.11.2026 na trzech maszynach GearPass w Sweden Central. Publiczny endpoint zwrócił HTTP 200 i JSON z gotowością PostgreSQL. W Log Analytics pojawiły się logi obu usług oraz próbki z każdej maszyny.

## E1 - budżet

Szablon `budget.bicep` tworzy budżet dla `rg-gearpass`. Budżet można wdrożyć oddzielnie od `resources.bicep`, który odpowiada za monitoring. W Azure ustawiono kwotę 10 EUR za miesiąc w walucie rozliczeniowej subskrypcji. Adresaci są parametrem przekazywanym w Azure. Progi 50, 80 i 100 procent wysyłają wiadomości na zweryfikowaną listę contactEmails zawierającą PM-a i członków zespołu. Budżet rozpoczyna się pierwszego dnia bieżącego miesiąca i resetuje co miesiąc. Obejmuje całą grupę rg-gearpass.

Alert budżetowy jest powiadomieniem. Koszty są aktualizowane z opóźnieniem, a alert nie zatrzymuje maszyn. Utrzymanie aplikacji do 6 grudnia wymaga sprawdzania aktualnego salda i kosztów pozostałych zasobów subskrypcji.

## E2 - gotowość aplikacji

GET /health wykonuje SELECT 1 w PostgreSQL i zwraca 200 z {"status":"UP","database":"UP"}. Niedostępna baza daje 503 i status DOWN. Brak konfiguracji PostgreSQL daje 503 i NOT_CONFIGURED. Dotychczasowy /api/health zachowuje format wykorzystywany przez frontend oraz CI/CD.

Wersję API na `vm-gearpass-app` aktualizuje się osobno od wdrożenia App Service z GitHub Actions. Po aktualizacji backendu uruchom `bash configure-health.sh` na `vm-gearpass-web`. Skrypt waliduje konfigurację Caddy przed przeładowaniem i instaluje timer `gearpass-health.timer`. Timer co minutę odpytuje prywatny backend z limitem 8 sekund, a błędy zapisuje w dzienniku usługi `gearpass-health.service`.

Po wdrożeniu sprawdź `curl -fsS https://gearpass-projekt-sc.swedencentral.cloudapp.azure.com/health` oraz `systemctl list-timers gearpass-health.timer` na Web. Zachowanie przy niedostępnej bazie sprawdza test backendu, który symuluje awarię poza produkcją.

## E3 - centralne logi

Wybrany wariant korzysta z Azure Monitor Agent na istniejącej maszynie Web. App i Data przekazują Syslog po prywatnym TCP 5514 do Web. NSG dopuszcza ten ruch tylko między wskazanymi prywatnymi adresami. DCR zbiera facility local0 (FastAPI), local1 (PostgreSQL) i local2 (CPU/RAM). Dane trafiają do tabeli Syslog w Log Analytics.

Przed uruchomieniem szablonu trzeba nadać istniejącej maszynie Web systemową tożsamość zarządzaną. Agent wymaga dostępnego wyjścia HTTPS do Azure Monitor i Azure Resource Manager oraz działającego DNS. Działający Web ma publiczny adres i wyjściowe TCP 443. App i Data zachowują prywatne adresy, a ich telemetria wychodzi do Web.

Na każdej VM należy sprawdzić obecność rsyslog, skopiować `configure-vm.sh`, `emit-metrics.py` oraz `configure-health.sh` i uruchomić skrypt z rolą web, app lub data jako root. Należy najpierw wdrożyć zmiany backendu. Skrypt ustawia logi systemd, przekazywanie Syslog i próbki CPU/RAM co 60 sekund. Na Data włącza logi połączeń PostgreSQL i zapis lokalny stderr. Zapytania SQL pozostają poza strumieniem logów.

Kod API zapisuje czas obsługi, kod HTTP i wzorzec ścieżki. Pomija query string, nagłówki i treść żądania. Do oceny błędów służy status_code. Czas duration_ms dotyczy obsługi w API.

## E4 - dashboard

Szablon tworzy współdzielony Azure Workbook „GearPass - CPU, RAM i API”. CPU i RAM dla każdej maszyny pochodzą z próbek Syslog co minutę. Pozostałe wykresy pokazują średni i p95 czas obsługi API oraz liczbę odpowiedzi według kodów. Tabela pokazuje logi FastAPI i PostgreSQL oraz ewentualne błędy sondy.

Po pierwszym wdrożeniu należy zaczekać na ingestę, wygenerować żądania testowe i sprawdzić każdy wykres. W portalu można włączyć automatyczne odświeżanie co 5 minut. To najkrótszy dostępny interwał odświeżania widoku. Maszyny wysyłają próbki co minutę. Puste wykresy wymagają sprawdzenia timerów, rsyslog, połączenia z agentem i DCR.

## Kontrola kosztów

Workspace używa PerGB2018, retencji 30 dni i dziennego limitu 0,05 GB. Faktyczna opłata zależy od stawki subskrypcji i ingestii. Limit jest mechanizmem ograniczenia wolumenu i może zostać przekroczony przez opóźnione zatrzymanie. Po osiągnięciu limitu dane mogą przestać napływać do kolejnego resetu.

Kolektor używa istniejącej maszyny Web. Plan zakłada pozostawienie trzech maszyn Standard_B1s i jednego publicznego IP. Przed wdrożeniem należy sprawdzić wolną pamięć Web i zapas kredytów do 6 grudnia. Należy ocenić dobową ingestę po uruchomieniu oraz koszt całej subskrypcji.

## Kolejność wdrożenia i dowody

1. Sprawdzić aktualne saldo, walutę, koszty i adresy odbiorców.
2. Wykonać Azure `what-if` dla `budget.bicep` z zatwierdzonymi parametrami i wdrożyć budżet w grupie `rg-gearpass`.
3. Zaktualizować backend na `vm-gearpass-app` i skonfigurować sondę na Web. Włączyć tożsamość zarządzaną Web, wykonać Azure `what-if` dla `resources.bicep`, wdrożyć monitoring i sprawdzić reguły NSG. Skopiować skrypty na VM i sprawdzić ich wykonanie.
4. Sprawdzić GET /health, dane w Syslog i wszystkie wykresy workbooka.
5. Zebrać zrzuty alertów, JSON z /health, logów, wykresów i sekcji README. W PDF opisać faktycznie wykonany wkład przy E1-E5.

Dokumentacja Microsoft
- https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets
- https://learn.microsoft.com/azure/azure-monitor/vm/data-collection-syslog
- https://learn.microsoft.com/azure/azure-monitor/agents/azure-monitor-agent-network-configuration
- https://learn.microsoft.com/azure/azure-monitor/logs/daily-cap
