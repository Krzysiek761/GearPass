GearPass - Bezpieczna wypożyczalnia sprzętu

GearPass to aplikacja chmurowa do rezerwacji i wypożyczania sprzętu (takiego jak aparaty, zestawy VR, konsole i mikrofony) w ramach jednej organizacji.Projekt umożliwia przeglądanie katalogu i dostępności, zarządzanie sprzętem i rezerwacjami oraz obsługę wydań i zwrotów z dokumentacją fotograficzną stanu urządzeń. Obejmuje logowanie, role użytkownika i opiekuna, kontrolę dostępu do danych, jednorazowe kody QR do potwierdzania odbioru oraz historię operacji.

Zespół "Grupa Specjalna"

(Podział ról)

Rola Imię i Nazwisko Numer studenta

PM (Project Manager) Adam Pajer 96736

DevOps Krzysztof Wojtkowiak 94750

Frontend Developer Krzysztof Wojtkowiak 94750

Backend Developer Krzysztof Wojtkowiak 94750 

DBA (Database Admin)Krzysztof Wojtkowiak 94750

## Architektura

[Publiczny GearPass](https://gearpass-projekt-sc.swedencentral.cloudapp.azure.com/) działa w Azure Sweden Central. W `vnet-gearpass` każda warstwa ma własną podsieć i NSG. Caddy na `vm-gearpass-web` obsługuje React, TLS oraz przekierowanie HTTP. Zapytania `/api/*` trafiają do FastAPI na `vm-gearpass-app`, a stan katalogu jest przechowywany w PostgreSQL na `vm-gearpass-data`.

Publiczny adres IP ma warstwa Web. Backend i PostgreSQL używają prywatnych adresów. PostgreSQL dodatkowo ogranicza logowanie do konta aplikacji i prywatnego adresu backendu. Operacje zapisu katalogu wymagają nagłówka `X-GearPass-Key`.

[Demo na App Service F1](https://gearpass-blok08-bcetfjepebbef8hq.swedencentral-01.azurewebsites.net/) działa niezależnie na danych demonstracyjnych. GitHub Actions wdraża tam zmiany z `main`. Wersja na maszynach w VNet jest wdrażana osobno.

![Szkic koncepcyjny architektury](docs/obraz.png)

## Reguły sieciowe (blok 09)

[Szablon sieci w Azure](config/azure/hardening-network.bicep) definiuje `vnet-gearpass` oraz NSG przypisane do trzech podsieci. Reguły w tabeli obowiązują na podsieciach działającego wdrożenia.

| Warstwa / podsieć | Kierunek | Źródło → cel | TCP | Decyzja |
| --- | --- | --- | --- | --- |
| Web · `snet-web` | Inbound | Internet → Web | 80, 443 | Zezwól |
| Web · `snet-web` | Outbound | Web → App | 8000 | Zezwól |
| Web · `snet-web` | Outbound | Web → Internet | 443 | Zezwól na odnowienie TLS |
| App · `snet-app` | Inbound | Web → App | 8000 | Zezwól |
| App · `snet-app` | Inbound | Internet → App | 22, 3389 | Blokuj |
| App · `snet-app` | Outbound | App → Data | 5432 | Zezwól |
| Data · `snet-data` | Inbound | App → Data | 5432 | Zezwól |
| Data · `snet-data` | Inbound | Internet → Data | 3306, 5432 | Blokuj |
| Web, App i Data | Inbound / Outbound | Pozostały ruch inicjowany | Wszystkie | Blokuj |

Tag `Internet` oznacza ruch z publicznego Internetu. Priorytety zezwoleń i blokad szczegółowych to 100 i 110. Reguły blokujące pozostały ruch mają priorytet 4096 i wyprzedzają domyślne reguły NSG. NSG są stanowe, więc odpowiedzi na dozwolone połączenia nie wymagają osobnych reguł.

Caddy pobiera i odnawia certyfikat publicznej domeny. Połączenie HTTP przekierowuje na HTTPS z zachowaniem ścieżki i parametrów. Na maszynach nie ma publicznego SSH ani RDP. Weryfikacja Azure Network Watcher potwierdziła zezwolenia Web → App i App → Data oraz blokady z Internetu.

## Dokumentacja API
| Metoda | Endpoint | Opis |
| :--- | :--- | :--- |
| GET | `/api/equipment` | Pobranie pełnej listy zasobów |
| POST | `/api/equipment` | Utworzenie nowego zasobu z walidacją |

## Instrukcja Uruchomienia Lokalnego
**Backend:** `cd backend` -> `uvicorn main:app --reload`
**Frontend:** `cd frontend` -> `npm install` -> `npm run dev`

## Monitoring i FinOps (blok 10)

Konfigurację przygotowano w [config/azure/monitoring](config/azure/monitoring/README.md). Stan wdrożenia tej gałęzi wymaga potwierdzenia w Azure.

- Budżet dla grupy `rg-gearpass` ma parametry kwoty w walucie rozliczeniowej i zweryfikowanych odbiorców. Progi wynoszą 50, 80 i 100 procent. Alerty wysyłają powiadomienia. Dostępne kredyty należy kontrolować do finału 6 grudnia.
- `GET /health` sprawdza `SELECT 1` w PostgreSQL. Zwraca `200` i `UP` po udanym połączeniu. Awaria bazy lub brak konfiguracji daje `503` i `DOWN`. Wdrożenie na VM wymaga aktualizacji backendu i reguły reverse proxy.
- FastAPI emituje JSON z czasem obsługi, kodem HTTP i wzorcem ścieżki. Strumień pomija nagłówki, parametry zapytania i treść żądania.
- Przygotowany kolektor przekazuje logi aplikacji, PostgreSQL i próbki CPU/RAM do Log Analytics przez istniejącą maszynę Web. Workspace ma retencję 30 dni i limit ingestii 0,05 GB/dobę. Opłaty zależą od faktycznego wolumenu, a egzekwowanie limitu może nastąpić z opóźnieniem.
- Azure Workbook zawiera wykresy CPU, RAM, czasu obsługi API i kodów odpowiedzi oraz tabelę logów. Dane i zrzuty trzeba zweryfikować po instalacji.

Szczegółowa kolejność wdrożenia, warunki sieciowe i testy znajdują się w instrukcji konfiguracji.
