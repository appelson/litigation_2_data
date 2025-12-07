# ---------------- Load required libraries -------------------------------------
library(tidyverse)
library(pdftools)
library(janitor)
library(stringdist)

# ------------------ Importing data -----------------------------------------
# Raw case and document data
filtered_texts <- read_csv("data/overview_data/filtered_texts.csv")
filtered_cases <- read_csv("data/overview_data/filtered_cases.csv")
filtered_pdfs <- read_csv("data/overview_data/pdf_documents.csv") %>%
  filter(document_id %in% filtered_texts$document_id)

# OpenAI-extracted structured data
agencies_openai_df <- read_csv("data/clean_data/openai_data/agencies_openai_df.csv")
officers_openai_df <- read_csv("data/clean_data/openai_data/officers_openai_df.csv")
plaintiffs_openai_df <- read_csv("data/clean_data/openai_data/plaintiffs_openai_df.csv")
causes_openai_df <- read_csv("data/clean_data/openai_data/causes_openai_df.csv")
misconduct_openai_df <- read_csv("data/clean_data/openai_data/misconduct_openai_df.csv")
locations_openai_df <- read_csv("data/clean_data/openai_data/locations_openai_df.csv")

# Initializing statistics container
stats <- list()

# -------------------- Document-level analysis ---------------------------------

# Counting total text  across all cases
n_texts <- nrow(filtered_texts)

# Total pages
pages <- list.files("data/raw_data/lex_complaints", 
                    full.names = TRUE, 
                    pattern = "\\.pdf$")

# Only documents in our analysis set
pages <- pages[basename(pages) %in% filtered_pdfs$file_names]

# Creating safe wrapper
safe_page_count <- possibly(
  ~ suppressWarnings(pdf_info(.x)$pages),
  otherwise = NA_integer_
)

# Extracting page counts
page_counts <- tibble(
  file = pages,
  n_pages = map_int(pages, safe_page_count)
)

# Getting total pages
total_pages <- sum(page_counts$n_pages, na.rm = TRUE)

# Calculating total character count across all documents
total_chars <- sum(nchar(filtered_texts$text_content), na.rm = TRUE)

# Tracking processing completeness
gpt_file_names <- list.files("data/extract/openai_extracted_text") %>%
  str_extract("^[^_]+")

# Counting files
n_files_processed <- length(gpt_file_names)

# Calculating missing
n_files_missing <- length(setdiff(filtered_texts$file_id, gpt_file_names))

# Counting unique cases that were successfully processed
n_cases_processed <- filtered_texts %>%
  filter(file_id %in% gpt_file_names) %>%
  pull(case_id) %>%
  n_distinct()

# -------------------- Case-level analysis -------------------------------------

# Total cases in dataset
n_cases <- nrow(filtered_cases)

# Case length
case_length_stats <- filtered_cases %>%
  summarise(
    mean_length = mean(length, na.rm = TRUE),
    median_length = median(length, na.rm = TRUE),
    sd_length = sd(length, na.rm = TRUE),
    min_length = min(length, na.rm = TRUE),
    max_length = max(length, na.rm = TRUE)
  )

# Geographic distribution
cases_by_state <- filtered_cases %>%
  tabyl(state) %>%
  arrange(desc(n))

# Counting parties involved
n_plaintiffs <- filtered_cases %>%
  mutate(plaintiff_list = str_split(plaintiff, "\n")) %>%
  unnest(plaintiff_list) %>%
  nrow()

# Counting defendants involved
n_defendants <- filtered_cases %>%
  mutate(defendant_list = str_split(defendant, "\n")) %>%
  unnest(defendant_list) %>%
  nrow()

# Complaint documents per case
complaints_per_case <- filtered_texts %>%
  group_by(case_id) %>%
  summarize(n = n(), .groups = "drop") %>%
  summarise(
    mean_complaints = mean(n, na.rm = TRUE),
    median_complaints = median(n, na.rm = TRUE),
    sd_complaints = sd(n, na.rm = TRUE),
    min_complaints = min(n, na.rm = TRUE),
    max_complaints = max(n, na.rm = TRUE)
  )

# Cases without associated documents
n_cases_no_docs <- length(setdiff(filtered_cases$case_id, filtered_texts$case_id))

# ---------------------- Document Coverage -------------------------------------

stats$data_validation <- list(
  agencies_docs = n_distinct(agencies_openai_df$filename),
  officers_docs = n_distinct(officers_openai_df$filename),
  plaintiffs_docs = n_distinct(plaintiffs_openai_df$filename),
  causes_docs = n_distinct(causes_openai_df$filename),
  misconduct_docs = n_distinct(misconduct_openai_df$filename),
  locations_docs = n_distinct(locations_openai_df$filename)
)


# ------------------------- Output -------------------------------------

# Basic counts
n_texts
total_pages
total_chars
n_files_processed
n_files_missing
n_cases_processed

# Case counts
n_cases
n_cases_no_docs
n_plaintiffs
n_defendants