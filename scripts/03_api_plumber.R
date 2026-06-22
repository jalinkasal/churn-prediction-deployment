library(plumber)
library(jsonlite)

source("helpers.R")
source("02_json_contract.R")

# Czas uruchomienia serwera
service_start_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

# Funkcja wykonuje predykcję dla pojedynczego rekordu batch
predict_single_batch_record <- function(client_obj, threshold, input_index) {
  validation_result <- validate_single_client(client_obj)
  
  if (!isTRUE(validation_result$ok)) {
    return(list(
      ok = FALSE,
      input_index = input_index,
      churn_probability = NULL,
      churn_class = NULL,
      risk_segment = NULL,
      recommended_action = NULL,
      error = list(
        error_code = validation_result$error_code,
        error_message = validation_result$error_message
      )
    ))
  }
  
  client_df <- validation_result$data
  prob_yes <- predict(model, newdata = client_df, type = "response")
  success_result <- build_success_response(prob_yes, threshold)
  
  list(
    ok = TRUE,
    input_index = input_index,
    churn_probability = success_result$churn_probability,
    churn_class = success_result$churn_class,
    risk_segment = success_result$risk_segment,
    recommended_action = success_result$recommended_action,
    error = NULL
  )
}

#* @apiTitle Churn Prediction API
#* @apiDescription API do predykcji churn na podstawie tenure, MonthlyCharges, TotalCharges.

#* Endpoint techniczny sprawdzający, czy usługa działa
#* @get /health
function() {
  list(
    status = "ok",
    service_start_time = service_start_time
  )
}

#* Predykcja churn dla pojedynczego klienta
#* @post /predict
#* @parser text
#* @param threshold Próg decyzyjny, domyślnie 0.5
function(req, res, threshold = 0.5) {
  threshold <- as.numeric(threshold)
  if (is.na(threshold)) threshold <- 0.5
  
  json_text <- req$postBody
  
  result <- tryCatch(
    predict_from_json(json_text, model, threshold),
    error = function(e) {
      build_error_response(
        error_code = "INTERNAL_SERVER_ERROR",
        error_message = "Wewnętrzny błąd serwera.",
        detail = list(message = "Wystąpił nieoczekiwany błąd podczas przetwarzania żądania.")
      )
    }
  )
  
  if (isTRUE(result$ok)) {
    res$status <- 200 # sukces
  } else if (result$error_code %in% c("INVALID_JSON", "MISSING_FIELDS", "INVALID_TYPES")) {
    res$status <- 400 # błąd w danych wejściowych
  } else {
    res$status <- 500 # błąd w serwerze
  }
  
  return(result)
}

#* Predykcja wsadowa dla wielu klientów
#* @post /predict_batch
#* @parser text
function(req, res) {
  batch_obj <- tryCatch(
    fromJSON(req$postBody, simplifyVector = FALSE),
    error = function(e) {
      return(build_error_response(
        error_code = "INVALID_JSON",
        error_message = "Niepoprawna składnia JSON.",
        detail = list(message = "Nie udało się odczytać danych wejściowych w formacie JSON.")
      ))
    }
  )
  
  if (!is.null(batch_obj$error_code)) {
    res$status <- 400
    return(batch_obj)
  }
  
  if (is.null(batch_obj$clients) || !is.list(batch_obj$clients)) {
    res$status <- 400
    return(build_error_response(
      error_code = "MISSING_CLIENTS",
      error_message = "Brakuje listy klientów 'clients' lub ma ona niepoprawny format.",
      detail = list()
    ))
  }
  
  threshold <- batch_obj$threshold
  if (is.null(threshold)) threshold <- 0.5
  threshold <- as.numeric(threshold)
  if (is.na(threshold)) threshold <- 0.5
  
  results <- vector("list", length(batch_obj$clients))
  
  for (i in seq_along(batch_obj$clients)) {
    results[[i]] <- predict_single_batch_record(
      client_obj = batch_obj$clients[[i]],
      threshold = threshold,
      input_index = i - 1
    )
  }
  
  res$status <- 200
  
  list(
    threshold = threshold,
    results = results
  )
}