library(tidyverse)
library(caret)
library(pROC)

# Wczytanie danych
data <- read.csv("data/raw/Telco-Customer-Churn.csv", stringsAsFactors = FALSE)

# Szybki przegląd
glimpse(data)
summary(data)

# Czyszczenie danych
data$TotalCharges <- as.numeric(data$TotalCharges)
data$MonthlyCharges <- as.numeric(data$MonthlyCharges)
data$tenure <- as.numeric(data$tenure)
data <- data %>% drop_na()
data$Churn <- as.factor(data$Churn)

# Kontrola po czyszczeniu
str(data$TotalCharges)
sum(is.na(data$TotalCharges))
str(data$MonthlyCharges)
sum(is.na(data$MonthlyCharges))
str(data$tenure)
sum(is.na(data$tenure))
table(data$Churn)
levels(data$Churn)

# Wybór cech do modelu bazowego
model_data <- data %>%
  select(tenure, MonthlyCharges, TotalCharges, Churn)

# Podział na zbiór treningowy i testowy
set.seed(123)

train_index <- createDataPartition(model_data$Churn, p = 0.8, list = FALSE)
train_data <- model_data[train_index, ]
test_data  <- model_data[-train_index, ]

# Budowa modelu bazowego - regresja logistyczna
churn_model <- glm(
  Churn ~ tenure + MonthlyCharges + TotalCharges,
  data = train_data,
  family = binomial
)

summary(churn_model)

# Predykcja prawdopodobieństw na zbiorze testowym
prob_yes <- predict(churn_model, newdata = test_data, type = "response")

# Zamiana prawdopodobieństw na klasy
pred_class <- ifelse(prob_yes >= 0.5, "Yes", "No")
pred_class <- factor(pred_class, levels = levels(test_data$Churn))

# Macierz pomyłek
cm <- confusionMatrix(pred_class, test_data$Churn, positive = "Yes")
print(cm)

# ROC i AUC
roc_obj <- roc(test_data$Churn, prob_yes, levels = c("No", "Yes"), direction = "<")
auc_value <- auc(roc_obj)

cat("AUC:", as.numeric(auc_value), "\n")

# Zapis modelu jako artefaktu
saveRDS(churn_model, "models/churn_model_v1.rds")

cat("Model zapisano do pliku: models/churn_model_v1.rds\n")
