# Projekt -- system predykcji churn

## Opis projektu

Projekt przedstawia uproszczony system end-to-end do predykcji churn klientów firmy telekomunikacyjnej. Został przygotowany w języku R na podstawie zbioru danych **Telco Customer Churn**. Rozwiązanie obejmuje model zapisany jako plik `.rds`, kontrakt wejścia i wyjścia w formacie JSON, lokalne REST API w `plumber`, aplikację `Shiny`, predykcję wsadową dla pliku CSV oraz smoke testy zapisujące raport do pliku JSON. Projekt wykorzystuje kontrakt wejściowy oparty na polach `tenure`, `MonthlyCharges` oraz `TotalCharges`, zgodnie z wymaganiami API i aplikacji Shiny.

## Dane

Projekt korzysta ze zbioru danych Telco Customer Churn.

Pełny plik danych `Telco-Customer-Churn.csv` nie został dołączony do repozytorium, ponieważ prawa do danych należą do oryginalnych autorów. Aby odtworzyć trenowanie modelu, należy pobrać dataset z oryginalnego źródła(https://www.kaggle.com/datasets/blastchar/telco-customer-churn) i umieścić plik w lokalizacji:

```text
data/raw/Telco-Customer-Churn.csv
```

W repozytorium znajduje się jedynie przykładowy plik do testowania predykcji wsadowej:

```text
data/examples/batch_test_c4.csv
```

## Uruchomienie projektu

Przed uruchomieniem projektu należy zainstalować pakiety:

``` r
install.packages(c("tidyverse", "caret", "pROC", "jsonlite", "plumber", "httr2", "shiny", "DT"))
```

Najpierw należy wytrenować model:

``` r
source("scripts/01_train_model.R")
```

Po wykonaniu skryptu model zostanie zapisany jako:

`models/churn_model_v1.rds`

Następnie należy uruchomić API:

``` r
source("scripts/03_run_api.R")
```

Usługa działa lokalnie pod adresem `http://127.0.0.1:8000` i udostępnia endpointy `GET /health`, `POST /predict` oraz `POST /predict_batch`.

W osobnej sesji tego samego projektu należy uruchomić aplikację Shiny:

``` r
source("scripts/04_app_shiny.R")
```

Aplikacja umożliwia wykonanie predykcji dla pojedynczego klienta oraz wgranie pliku CSV i uruchomienie batch prediction.

Przy działającym API można uruchomić smoke testy:

``` r
source("scripts/05_smoke_tests.R")
```

Wynik testów zostanie zapisany w pliku `tests/test_report.json`.

## Wybrane składniki projektu

### `POST /predict_batch`

**Cel**\
Składnik umożliwia wykonanie predykcji churn dla wielu klientów w jednym żądaniu. Endpoint przetwarza listę rekordów wejściowych i zwraca wynik osobno dla każdego klienta. Błędny rekord nie przerywa przetwarzania całego batcha.

**Endpoint/UI**\
Endpoint API: `POST /predict_batch`\
W aplikacji `Shiny` składnik jest używany w zakładce **Predykcja wsadowa (batch)** po wgraniu pliku CSV.

**Przykład wejścia**

``` json
{
  "clients": [
    {
      "tenure": 12,
      "MonthlyCharges": 79.85,
      "TotalCharges": 950.20
    },
    {
      "tenure": "dwanaście",
      "MonthlyCharges": 79.85,
      "TotalCharges": 950.20
    }
  ],
  "threshold": 0.5
}
```

**Przykład wyjścia**

``` json
{
  "threshold": 0.5,
  "results": [
    {
      "ok": true,
      "input_index": 0,
      "churn_probability": 0.5352,
      "churn_class": "Yes",
      "risk_segment": "medium",
      "recommended_action": "Wyślij klientowi ofertę retencyjną e-mailem.",
      "error": null
    },
    {
      "ok": false,
      "input_index": 1,
      "churn_probability": null,
      "churn_class": null,
      "risk_segment": null,
      "recommended_action": null,
      "error": {
        "error_code": "INVALID_TYPES",
        "error_message": "Jedno lub więcej wymaganych pól nie daje się przekonwertować na typ numeryczny."
      }
    }
  ]
}
```

**Minimalny test**\
Należy wysłać batch zawierający co najmniej jeden rekord poprawny i jeden błędny. Oczekiwany wynik: poprawny rekord otrzymuje predykcję, a błędny rekord otrzymuje `ok = false` i komunikat błędu, bez przerwania całego batcha.

### Statusy HTTP + stały format błędów

**Cel**\
Składnik zapewnia spójny sposób obsługi błędów w API. Odpowiedzi sukcesu i błędu mają przewidywalną strukturę, a endpointy zwracają odpowiednie statusy HTTP.

**Endpoint/UI**\
Dotyczy endpointów `POST /predict` oraz `POST /predict_batch`. W przypadku błędów walidacji API zwraca status `400`, a przy poprawnym przetworzeniu `200`.

**Przykład wejścia**

``` json
{
  "tenure": 12,
  "MonthlyCharges": 79.85
}
```

**Przykład wyjścia**

``` json
{
  "ok": false,
  "error_code": "MISSING_FIELDS",
  "error_message": "Brakuje wymaganych pól wejściowych.",
  "detail": {
    "missing_fields": ["TotalCharges"]
  }
}
```

**Minimalny test**\
Należy wysłać niepoprawne dane wejściowe, np. z brakującym polem lub błędnym typem. Oczekiwany wynik: API zwraca status `400` oraz JSON zawierający `error_code`, `error_message` i `detail`.

### Batch upload + błędy per rekord

**Cel**\
Składnik umożliwia użytkownikowi wgranie pliku CSV w aplikacji `Shiny` i wykonanie predykcji wsadowej bez ręcznego tworzenia JSON. Wyniki oraz błędy są prezentowane osobno dla każdego rekordu.

**Endpoint/UI**\
Zakładka `Predykcja wsadowa (batch)` w aplikacji `Shiny`.

**Przykład wejścia**

Przykładowy plik CSV używany do testu składnika znajduje się w projekcie pod ścieżką:

`data/examples/batch_test_c4.csv`

Przykładowa zawartość pliku:

``` csv
tenure,MonthlyCharges,TotalCharges
12,79.85,950.20
24,60.50,1450.10
36,95.30,3200.40
8,45.00,360.00
dwanaście,79.85,950.20
```

**Przykład wyjścia**\
W aplikacji wyświetlana jest tabela zawierająca m.in. pola `input_index`, `ok`, `churn_probability`, `churn_class`, `risk_segment`, `recommended_action`, `error_code` oraz `error_message`. Dla błędnego rekordu pojawia się np. `INVALID_TYPES`.

**Minimalny test**\
Należy wgrać plik `data/examples/batch_test_c4.csv`, zawierający 5 wierszy, z czego 1 wiersz jest błędny. Oczekiwany wynik: poprawne rekordy otrzymują wynik predykcji, a błędny rekord otrzymuje komunikat błędu w tabeli, bez przerwania przetwarzania całego batcha.

### Smoke tests + raport JSON

**Cel**\
Składnik służy do szybkiego sprawdzenia, czy podstawowe endpointy API działają poprawnie oraz czy projekt jest gotowy do uruchomienia.

**Endpoint/UI**\
Skrypt: `scripts/05_smoke_tests.R`\
Raport: `tests/test_report.json`

**Przykład wejścia**

``` r
source("scripts/05_smoke_tests.R")
```

**Przykład wyjścia**

``` json
[
  {
    "test_name": "GET /health",
    "passed": true,
    "status_http": 200,
    "duration_ms": 15.21,
    "error": null
  },
  {
    "test_name": "POST /predict",
    "passed": true,
    "status_http": 200,
    "duration_ms": 24.57,
    "error": null
  },
  {
    "test_name": "POST /predict_batch",
    "passed": true,
    "status_http": 200,
    "duration_ms": 31.84,
    "error": null
  }
]
```

**Minimalny test**\
Przy działającym API należy uruchomić skrypt smoke testów. Oczekiwany wynik: testy dla `/health`, `/predict` i `/predict_batch` kończą się sukcesem, a raport zostaje zapisany do pliku `tests/test_report.json`.

### Segmentacja ryzyka + rekomendowana akcja

**Cel**\
Składnik rozszerza wynik modelu o interpretację biznesową. Oprócz prawdopodobieństwa churn użytkownik otrzymuje segment ryzyka oraz sugerowaną akcję retencyjną.

**Endpoint/UI**\
Dotyczy endpointów `POST /predict` i `POST /predict_batch` oraz aplikacji `Shiny`, gdzie segment ryzyka i rekomendowana akcja są prezentowane użytkownikowi.

**Przykład wejścia**

``` json
{
  "tenure": 12,
  "MonthlyCharges": 79.85,
  "TotalCharges": 950.20
}
```

**Przykład wyjścia**

``` json
{
  "ok": true,
  "churn_probability": 0.5352,
  "churn_class": "Yes",
  "threshold": 0.5,
  "risk_segment": "medium",
  "recommended_action": "Wyślij klientowi ofertę retencyjną e-mailem."
}
```

**Minimalny test**\
Należy wykonać predykcję dla pojedynczego klienta i sprawdzić, czy odpowiedź zawiera pola `risk_segment` oraz `recommended_action`. Oczekiwany wynik: użytkownik otrzymuje nie tylko klasę i prawdopodobieństwo, ale także interpretację ryzyka i sugestię działania.

## Uwagi końcowe

Projekt należy uruchamiać z poziomu tego samego projektu RStudio, aby poprawnie działały ścieżki względne. Najpierw należy uruchomić API, a dopiero potem aplikację Shiny i smoke testy.
