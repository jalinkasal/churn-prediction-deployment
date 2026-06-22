library(plumber)

# Uruchomienie API
api <- plumb("scripts/03_api_plumber.R")
api$run(host = "127.0.0.1", port = 8000)
