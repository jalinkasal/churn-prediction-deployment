library(shiny)
library(httr2)
library(jsonlite)
library(DT)

# Bazowy adres lokalnego API
base_url <- "http://127.0.0.1:8000"

# Funkcja wysyła pojedynczy rekord do API /predict
# Wejście:
# - json_text: dane jednego klienta w formacie JSON
# - threshold: próg decyzyjny
# Wyjście:
# - lista z odpowiedzią API
call_predict_api <- function(json_text, threshold = 0.5) {
  tryCatch({
    resp <- request(paste0(base_url, "/predict")) |>
      req_method("POST") |>
      req_url_query(threshold = threshold) |>
      req_headers(`Content-Type` = "application/json") |>
      req_body_raw(json_text) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()
    
    fromJSON(resp_body_string(resp), simplifyVector = TRUE)
  }, error = function(e) {
    list(
      ok = FALSE,
      error_code = "CLIENT_REQUEST_ERROR",
      error_message = "Nie udało się połączyć z API.",
      detail = list(message = e$message)
    )
  })
}

# Funkcja wysyła batch do API /predict_batch
# Wejście:
# - json_text: dane wielu klientów w formacie JSON
# Wyjście:
# - lista z odpowiedzią API
call_predict_batch_api <- function(json_text) {
  tryCatch({
    resp <- request(paste0(base_url, "/predict_batch")) |>
      req_method("POST") |>
      req_headers(`Content-Type` = "application/json") |>
      req_body_raw(json_text) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform()
    
    fromJSON(resp_body_string(resp), simplifyVector = FALSE)
  }, error = function(e) {
    list(
      ok = FALSE,
      error_code = "CLIENT_REQUEST_ERROR",
      error_message = "Nie udało się połączyć z API.",
      detail = list(message = e$message)
    )
  })
}

# Funkcja bezpiecznie wyciąga pojedynczą wartość z odpowiedzi API
# Wejście:
# - x: pole odpowiedzi API
# Wyjście:
# - pojedyncza wartość albo NA
extract_scalar <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(NA)
  }
  
  if (is.list(x)) {
    if (length(x) == 0) {
      return(NA)
    }
    return(x[[1]])
  }
  
  x
}

ui <- fluidPage(
  titlePanel("System predykcji churn"),
  
  tabsetPanel(
    tabPanel(
      "Predykcja pojedyncza",
      br(),
      
      numericInput("tenure", "Tenure", value = 12, min = 0),
      numericInput("monthly", "MonthlyCharges", value = 79.85, min = 0),
      numericInput("total", "TotalCharges", value = 950.20, min = 0),
      numericInput("threshold_single", "Threshold", value = 0.5, min = 0, max = 1, step = 0.01),
      
      actionButton("predict_btn", "Oblicz predykcję"),
      br(), br(),
      
      verbatimTextOutput("single_result"),
      verbatimTextOutput("single_error")
    ),
    
    tabPanel(
      "Predykcja wsadowa (batch)",
      br(),
      
      fileInput("batch_file", "Wgraj plik CSV", accept = ".csv"),
      numericInput("threshold_batch", "Threshold", value = 0.5, min = 0, max = 1, step = 0.01),
      
      actionButton("batch_btn", "Uruchom batch"),
      br(), br(),
      
      verbatimTextOutput("batch_message"),
      DTOutput("batch_table")
    )
  )
)

server <- function(input, output, session) {
  
  # Obsługa predykcji pojedynczej
  observeEvent(input$predict_btn, {
    output$single_error <- renderText("")
    output$single_result <- renderText("")
    
    if (is.null(input$tenure) || is.na(input$tenure) ||
        is.null(input$monthly) || is.na(input$monthly) ||
        is.null(input$total) || is.na(input$total)) {
      output$single_error <- renderText({
        "Błąd: MISSING_FIELDS\nBrakuje wymaganych pól wejściowych."
      })
      return()
    }
    
    client_data <- list(
      tenure = input$tenure,
      MonthlyCharges = input$monthly,
      TotalCharges = input$total
    )
    
    json_text <- toJSON(client_data, auto_unbox = TRUE)
    
    result <- call_predict_api(json_text, threshold = input$threshold_single)
    
    if (isTRUE(result$ok)) {
      output$single_result <- renderText({
        paste0(
          "Prawdopodobieństwo churn: ", round(result$churn_probability, 4), "\n",
          "Klasa: ", result$churn_class, "\n",
          "Threshold: ", result$threshold, "\n",
          "Segment ryzyka: ", result$risk_segment, "\n",
          "Rekomendowana akcja: ", result$recommended_action
        )
      })
    } else {
      output$single_error <- renderText({
        error_code <- if (!is.null(result$error_code)) result$error_code else "BRAK_KODU_BŁĘDU"
        error_message <- if (!is.null(result$error_message)) result$error_message else "API zwróciło odpowiedź w nieoczekiwanym formacie."
        
        paste0(
          "Błąd: ", error_code, "\n",
          error_message
        )
      })
    }
  })
  
  # Obsługa batch upload
  observeEvent(input$batch_btn, {
    output$batch_message <- renderText("")
    output$batch_table <- renderDT(NULL)
    
    if (is.null(input$batch_file)) {
      output$batch_message <- renderText("Najpierw wgraj plik CSV.")
      return()
    }
    
    batch_data <- tryCatch({
      read.csv(input$batch_file$datapath, stringsAsFactors = FALSE)
    }, error = function(e) {
      NULL
    })
    
    if (is.null(batch_data)) {
      output$batch_message <- renderText("Nie udało się odczytać pliku CSV.")
      return()
    }
    
    required_cols <- c("tenure", "MonthlyCharges", "TotalCharges")
    
    missing_cols <- setdiff(required_cols, names(batch_data))
    
    if (length(missing_cols) > 0) {
      output$batch_message <- renderText({
        paste0(
          "Brakuje wymaganych kolumn w pliku CSV: ",
          paste(missing_cols, collapse = ", ")
        )
      })
      return()
    }
    
    clients_list <- lapply(seq_len(nrow(batch_data)), function(i) {
      list(
        tenure = batch_data$tenure[i],
        MonthlyCharges = batch_data$MonthlyCharges[i],
        TotalCharges = batch_data$TotalCharges[i]
      )
    })
    
    batch_request <- list(
      clients = clients_list,
      threshold = input$threshold_batch
    )
    
    json_text <- toJSON(batch_request, auto_unbox = TRUE)
    
    result <- call_predict_batch_api(json_text)
    
    print(result)
    str(result)
    
    if (!is.null(result$results)) {
      table_data <- lapply(result$results, function(x) {
  error_code <- NA
  error_message <- NA

  if (!is.null(x$error) && length(x$error) > 0) {
    error_code <- extract_scalar(x$error$error_code)
    error_message <- extract_scalar(x$error$error_message)
  }

  data.frame(
    input_index = extract_scalar(x$input_index),
    ok = extract_scalar(x$ok),
    churn_probability = extract_scalar(x$churn_probability),
    churn_class = extract_scalar(x$churn_class),
    risk_segment = extract_scalar(x$risk_segment),
    recommended_action = extract_scalar(x$recommended_action),
    error_code = error_code,
    error_message = error_message,
    stringsAsFactors = FALSE
  )
})
      
      table_data <- do.call(rbind, table_data)
      
      output$batch_message <- renderText({
        "Batch został przetworzony."
      })
      
      output$batch_table <- renderDT({
        datatable(table_data, options = list(pageLength = 10))
      })
    } else {
      output$batch_message <- renderText({
        paste0(
          "Błąd: ", result$error_code, "\n",
          result$error_message
        )
      })
    }
  })
}

runApp(shinyApp(ui = ui, server = server))
