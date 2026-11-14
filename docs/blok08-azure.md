# Blok 08 – GearPass na Azure App Service

App Service (Linux, Python 3.12, F1) publikuje statyczny frontend React i FastAPI pod jedną domeną HTTPS. Azure for Students dopuszcza Sweden Central, a dostępne regiony Static Web Apps były poza listą tej subskrypcji.

GitHub Actions loguje się przez OIDC. Tożsamość użytkownika zarządzana przez Azure ma federację tylko dla repo:Krzysiek761/GearPass:ref:refs/heads/main, audience api://AzureADTokenExchange i Website Contributor tylko dla aplikacji gearpass-blok08. Ustaw zmienną repozytorium AZURE_DEPLOY_CONFIG jako JSON z polami clientId, tenantId oraz subscriptionId. Wartości to identyfikatory, bez hasła lub klucza.

Workflow pakuje kod, frontend, zależności i SHA oraz sprawdza pakiet po zaliczeniu skanerów i testów. Push na main publikuje sprawdzony ZIP. Healthcheck potwierdza publiczną stronę, /version.json, /api/health i /api/equipment. Frontend korzysta z dotychczasowych danych demonstracyjnych. Aplikacja używa wspólnego hosta F1 dla obu warstw, bez odrębnej prywatnej podsieci API.
