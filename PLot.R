# Load libraries
library(ggplot2)
library(dplyr)
library(tidyr)

# Step 1: Simulate sample BP data based on raw_lb_data_hypertension.xlsx format
bp_data <- tibble::tribble(
  ~USUBJID,        ~LBDTC,        ~LBTEST,          ~LBSTRESN,
  "HTN001-003-001", "2024-01-24", "Systolic BP",    145,
  "HTN001-003-001", "2024-01-24", "Diastolic BP",   95,
  "HTN001-003-001", "2024-01-31", "Systolic BP",    140,
  "HTN001-003-001", "2024-01-31", "Diastolic BP",   90,
  "HTN001-001-008", "2024-01-08", "Systolic BP",    138,
  "HTN001-001-008", "2024-01-08", "Diastolic BP",   88,
  "HTN001-001-008", "2024-01-15", "Systolic BP",    132,
  "HTN001-001-008", "2024-01-15", "Diastolic BP",   85,
  "HTN001-003-009", "2024-01-26", "Systolic BP",    150,
  "HTN001-003-009", "2024-01-26", "Diastolic BP",   98,
  "HTN001-003-009", "2024-02-02", "Systolic BP",    142,
  "HTN001-003-009", "2024-02-02", "Diastolic BP",   92,
  "HTN001-001-017", "2024-01-28", "Systolic BP",    148,
  "HTN001-001-017", "2024-01-28", "Diastolic BP",   94,
  "HTN001-001-017", "2024-02-04", "Systolic BP",    140,
  "HTN001-001-017", "2024-02-04", "Diastolic BP",   90
)

# Convert date
bp_data <- bp_data %>%
  mutate(LBDTC = as.Date(LBDTC))

# Pivot wider to get systolic and diastolic in separate columns
bp_wide <- bp_data %>%
  pivot_wider(
    names_from = LBTEST,
    values_from = LBSTRESN
  )

# Calculate MAP
bp_wide <- bp_wide %>%
  mutate(MAP = ((2 * `Diastolic BP`) + `Systolic BP`) / 3)

# View the derived data
print(bp_wide)

# Step 2: Plot using ggplot2
ggplot(bp_wide, aes(x = LBDTC, y = MAP, color = USUBJID, group = USUBJID)) +
  geom_line(size = 1.2) +
  geom_point(size = 2.5) +
  labs(
    title = "Mean Arterial Pressure (MAP) Over Time",
    x = "Date",
    y = "Mean Arterial Pressure (mmHg)",
    color = "Subject ID"
  ) 