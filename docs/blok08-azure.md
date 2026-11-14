# Wdrożenie GearPass do Azure

1. W aktywnej subskrypcji projektu utwórz Azure Static Web Apps (Free, środowisko laboratoryjne). Jako źródło wybierz Other, aby korzystać z workflow w tym repozytorium. Web jest publikowany w Static Web Apps, a backend działa jako zarządzana funkcja HTTP pod tą samą domeną.
2. W Overview ustaw politykę wdrożenia na Azure deployment token i pobierz token z Manage deployment token. W GearPass wybierz Settings → Secrets and variables → Actions → New repository secret. Zapisz go jako AZURE_STATIC_WEB_APPS_API_TOKEN. Token udziela dostępu do publikacji na tej witrynie. Nie wklejaj go do kodu ani opisu PR.
3. Scal przez chronioną gałąź main. GearPass CI odpala skanery, lint, build i testy, a następnie wywołuje deploy.yml przez needs. Pull request buduje i testuje pakiet. Publikacja do Azure działa po push na main.
4. W GitHub Actions otwórz ostatni udany przebieg dla main. Podsumowanie healthchecku zawiera publiczny adres HTTPS i commit. Ręcznie otwórz stronę, /version.json, /api/health i /api/equipment. Wartość commit w pierwszych dwóch odpowiedziach JSON powinna odpowiadać commitowi z przebiegu.

Backend wykorzystuje istniejące dane demonstracyjne i uruchamia FastAPI przez adapter Azure Functions. Wdrożenie z Bloku 8 nie wymaga tworzenia PostgreSQL ani zmiany istniejącej sieci Azure.
