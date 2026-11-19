# Blok 08 – GearPass na Azure App Service

App Service (Linux, Python 3.12) publikuje statyczny frontend React i FastAPI pod jedną domeną HTTPS. Azure for Students dopuszcza Sweden Central, a dostępne regiony Static Web Apps były poza listą tej subskrypcji.

GitHub Actions loguje się przez OIDC. Tożsamość użytkownika zarządzana przez Azure ma federację tylko dla repo:Krzysiek761@213234395/GearPass@1412884563:ref:refs/heads/main, audience api://AzureADTokenExchange i Website Contributor tylko dla wskazanej aplikacji GearPass. Ustaw zmienną repozytorium AZURE_DEPLOY_CONFIG jako JSON z polami clientId, tenantId oraz subscriptionId. W razie zmiany zasobu dodaj appName i resourceGroup do tego samego JSON. Wartości to identyfikatory, bez hasła lub klucza.

Workflow pakuje kod, frontend, zależności i SHA oraz sprawdza pakiet po zaliczeniu skanerów i testów. Push na main wysyła sprawdzony ZIP asynchronicznie, a zakończenie wdrożenia ustala na podstawie odpowiedzi publicznych endpointów. Healthcheck potwierdza publiczną stronę, /version.json, /api/health i /api/equipment. Frontend korzysta z dotychczasowych danych demonstracyjnych. Aplikacja używa wspólnego hosta App Service dla obu warstw, bez odrębnej prywatnej podsieci API.
