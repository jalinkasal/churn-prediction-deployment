library(jsonlite)

# Wymagane pola wejściowe 
required_fields <- c("tenure", "MonthlyCharges", "TotalCharges")

# Funkcja buduje ujednoliconą odpowiedź błędu
# Wejście:
# - error_code: techniczny kod błędu
# - error_message: komunikat dla użytkownika / klienta API
# - detail: dodatkowe szczegóły błędu
# Wyjście:
# - lista z informacją o błędzie
build_error_response <- function(error_code, error_message, detail = list()) {
  list(
    ok = FALSE,
    error_code = error_code,
    error_message = error_message,
    detail = detail
  )
}

# Funkcja przypisuje segment ryzyka i sugerowaną akcję
# Wejście:
# - prob_yes: prawdopodobieństwo churn
# Wyjście:
# - lista z polami segment i action
get_risk_segment <- function(prob_yes) {
  if (prob_yes < 0.30) {
    return(list(
      segment = "low",
      action = "Brak natychmiastowej akcji – wystarczy standardowy monitoring."
    ))
  }
  
  if (prob_yes < 0.70) {
    return(list(
      segment = "medium",
      action = "Wyślij klientowi ofertę retencyjną e-mailem."
    ))
  }
  
  list(
    segment = "high",
    action = "Skontaktuj się z klientem telefonicznie i zaproponuj działanie retencyjne."
  )
}

# Funkcja buduje ujednoliconą odpowiedź sukcesu
# Wejście:
# - prob_yes: prawdopodobieństwo churn
# - threshold: próg decyzyjny
# Wyjście:
# - lista z wynikiem predykcji
build_success_response <- function(prob_yes, threshold) {
  churn_class <- ifelse(prob_yes >= threshold, "Yes", "No")
  
  risk_info <- get_risk_segment(prob_yes)
  
  list(
    ok = TRUE,
    churn_probability = as.numeric(prob_yes),
    churn_class = as.character(churn_class),
    threshold = as.numeric(threshold),
    risk_segment = risk_info$segment,
    recommended_action = risk_info$action
  )
}

# Funkcja sprawdza pojedynczy rekord klienta
# Wejście:
# - obj: obiekt po parsowaniu JSON
# Wyjście:
# - jeśli dane są poprawne: lista z ok = TRUE i data.frame
# - jeśli dane są błędne: lista z odpowiedzią błędu
validate_single_client <- function(obj) {
  missing_fields <- setdiff(required_fields, names(obj))
  
  if (length(missing_fields) > 0) {
    return(build_error_response(
      error_code = "MISSING_FIELDS",
      error_message = "Brakuje wymaganych pól wejściowych.",
      detail = list(missing_fields = missing_fields)
    ))
  }
  
  df <- as.data.frame(obj)
  
  df$tenure <- as.numeric(df$tenure)
  df$MonthlyCharges <- as.numeric(df$MonthlyCharges)
  df$TotalCharges <- as.numeric(df$TotalCharges)
  
  invalid_fields <- required_fields[is.na(df[1, required_fields])]
  
  if (length(invalid_fields) > 0) {
    return(build_error_response(
      error_code = "INVALID_TYPES",
      error_message = "Jedno lub więcej wymaganych pól nie daje się przekonwertować na typ numeryczny.",
      detail = list(invalid_fields = invalid_fields)
    ))
  }
  
  list(
    ok = TRUE,
    data = df[, required_fields, drop = FALSE]
  )
}
