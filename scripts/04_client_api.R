library(httr2)
library(jsonlite)

# Adres bazowy lokalnego API
base_url <- "http://127.0.0.1:8000"

# Funkcja sprawdza endpoint /health
safe_get_health <- function() {
  tryCatch({
    resp <- request(paste0(base_url, "/health")) |>
      req_method("GET") |>
      req_perform()
    
    resp_body_string(resp)
  }, error = function(e) {
    paste("ERROR:", e$message)
  })
}

# Funkcja wysyła pojedynczy rekord do /predict
safe_post_predict <- function(json_text, threshold = 0.5) {
  tryCatch({
    resp <- request(paste0(base_url, "/predict")) |>
      req_method("POST") |>
      req_url_query(threshold = threshold) |>
      req_headers(`Content-Type` = "application/json") |>
      req_body_raw(json_text) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()
    
    status_code <- resp_status(resp)
    response_text <- resp_body_string(resp)
    
    if (status_code %in% c(200, 400, 500)) {
      return(fromJSON(response_text, simplifyVector = FALSE))
    }
    
    list(
      ok = FALSE,
      error_code = "UNEXPECTED_STATUS",
      error_message = "API zwróciło nieoczekiwany kod statusu HTTP.",
      detail = list(status_code = status_code)
    )
  }, error = function(e) {
    list(
      ok = FALSE,
      error_code = "CLIENT_REQUEST_ERROR",
      error_message = "Nie udało się połączyć z API albo odebrać odpowiedzi.",
      detail = list(message = e$message)
    )
  })
}

# Funkcja wysyła batch do /predict_batch
safe_post_predict_batch <- function(json_text) {
  tryCatch({
    resp <- request(paste0(base_url, "/predict_batch")) |>
      req_method("POST") |>
      req_headers(`Content-Type` = "application/json") |>
      req_body_raw(json_text) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()
    
    status_code <- resp_status(resp)
    response_text <- resp_body_string(resp)
    
    if (status_code %in% c(200, 400, 500)) {
      return(fromJSON(response_text, simplifyVector = FALSE))
    }
    
    list(
      ok = FALSE,
      error_code = "UNEXPECTED_STATUS",
      error_message = "API zwróciło nieoczekiwany kod statusu HTTP.",
      detail = list(status_code = status_code)
    )
  }, error = function(e) {
    list(
      ok = FALSE,
      error_code = "CLIENT_REQUEST_ERROR",
      error_message = "Nie udało się połączyć z API albo odebrać odpowiedzi.",
      detail = list(message = e$message)
    )
  })
}