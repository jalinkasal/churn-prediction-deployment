library(httr2)
library(jsonlite)

base_url <- "http://127.0.0.1:8000"

# Funkcja wykonuje pojedynczy test HTTP i zapisuje wynik w ujednoliconej formie
# Wejście:
# - test_name: nazwa testu
# - expr: kod wykonujący request
# Wyjście:
# - lista z wynikiem testu
run_smoke_test <- function(test_name, expr) {
  start_time <- Sys.time()
  
  result <- tryCatch({
    resp <- force(expr)
    
    duration_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    status_http <- resp_status(resp)
    response_text <- resp_body_string(resp)
    
    list(
      test_name = test_name,
      passed = status_http == 200,
      status_http = status_http,
      duration_ms = round(duration_ms, 2),
      error = if (status_http == 200) NA else response_text
    )
  }, error = function(e) {
    duration_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    
    list(
      test_name = test_name,
      passed = FALSE,
      status_http = NA,
      duration_ms = round(duration_ms, 2),
      error = e$message
    )
  })
  
  result
}


# Dane testowe
good_json <- '{
  "tenure": 12,
  "MonthlyCharges": 79.85,
  "TotalCharges": 950.20
}'

batch_json <- '{
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
}'


# Uruchomienie testów
test_results <- list(
  run_smoke_test(
    "GET /health",
    request(paste0(base_url, "/health")) |>
      req_method("GET") |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()
  ),
  
  run_smoke_test(
    "POST /predict",
    request(paste0(base_url, "/predict")) |>
      req_method("POST") |>
      req_url_query(threshold = 0.5) |>
      req_headers(`Content-Type` = "application/json") |>
      req_body_raw(good_json) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()
  ),
  
  run_smoke_test(
    "POST /predict_batch",
    request(paste0(base_url, "/predict_batch")) |>
      req_method("POST") |>
      req_headers(`Content-Type` = "application/json") |>
      req_body_raw(batch_json) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()
  )
)

# Podgląd wyników w konsoli
print(test_results)

# Zapis raportu do pliku JSON
report_json <- toJSON(test_results, auto_unbox = TRUE, pretty = TRUE, null = "null")
writeLines(report_json, "tests/test_report.json")

cat("Raport zapisano do pliku: tests/test_report.json\n")