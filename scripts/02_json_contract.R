library(jsonlite)

source("helpers.R")

# Wczytanie gotowego modelu
model <- readRDS("../models/churn_model_v1.rds")

# Funkcja wykonuje pełny proces predykcji z JSON:
# JSON -> parsowanie -> walidacja -> data.frame -> predict() -> wynik
# Wejście:
# - json_text: tekst w formacie JSON
# - model: wcześniej zapisany model .rds
# - threshold: próg decyzyjny
# Wyjście:
# - lista z wynikiem lub kontrolowanym błędem
predict_from_json <- function(json_text, model, threshold = 0.5) {
  parsed_obj <- tryCatch(
    fromJSON(json_text),
    error = function(e) {
      return(build_error_response(
        error_code = "INVALID_JSON",
        error_message = "Niepoprawna składnia JSON.",
        detail = list(
          message = "Nie udało się odczytać danych wejściowych w formacie JSON.",
          technical_message = e$message
        )
      ))
    }
  )
  
  if (!is.null(parsed_obj$error_code)) {
    return(parsed_obj)
  }
  
  validation_result <- validate_single_client(parsed_obj)
  
  if (!isTRUE(validation_result$ok)) {
    return(validation_result)
  }
  
  client_df <- validation_result$data
  
  prob_yes <- predict(model, newdata = client_df, type = "response")
  
  build_success_response(prob_yes = prob_yes, threshold = threshold)
}

# Funkcja zamienia wynik predykcji na tekst JSON
# Wejście:
# - json_text: wejściowy JSON klienta
# - model: model predykcyjny
# - threshold: próg decyzyjny
# Wyjście:
# - tekst JSON gotowy do odesłania przez API
predict_from_json_text <- function(json_text, model, threshold = 0.5) {
  result <- predict_from_json(json_text, model, threshold)
  
  toJSON(result, auto_unbox = TRUE, pretty = TRUE, null = "null")
}
