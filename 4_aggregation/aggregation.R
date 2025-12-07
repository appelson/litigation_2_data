# -------------------------------- LIBRARIES --------------------------------
library(jsonlite)
library(dplyr)
library(stringr)
library(tidyverse)
library(purrr)
library(readr)

`%||%` <- function(x, y) if (is.null(x)) y else x


# -------------------------------- HELPERS --------------------------------
extract_code <- function(filename) {
  sub("_.*$", "", filename)
}

normalize_text <- function(x) {
  x %>%
    as.character() %>%
    str_to_lower() %>%
    str_replace_all("[\u2018\u2019]", "'") %>%
    str_replace_all("[\u201C\u201D]", "\"") %>%
    str_replace_all("[[:cntrl:]]", " ") %>%
    str_replace_all("\\s+", " ") %>%
    str_trim()
}

normalize_df <- function(df) {
  if (!is.data.frame(df)) return(df)
  df %>% mutate(across(where(is.character), normalize_text))
}

apply_code <- function(df) {
  if (!is.data.frame(df)) return(df)
  if (!"filename" %in% names(df)) return(df)
  df %>% mutate(code = extract_code(filename))
}

strip_fences <- function(txt) {
  txt <- str_trim(txt)
  txt <- sub("^```[A-Za-z0-9]*\\s*\n", "", txt)
  txt <- sub("\n?```$", "", txt)
  str_trim(txt)
}

safe_rows <- function(x) {
  x <- compact(x)
  if (length(x) == 0) tibble() else bind_rows(x)
}


# -------------------------------- LOAD INPUT --------------------------------
cases <- read_csv("data/overview_data/filtered_cases.csv")
text  <- read_csv("data/overview_data/text_documents.csv")

docs <- text %>%
  select(code = file_id, case_id, order, total_documents)

folder_openai <- "data/extract/openai_extracted_text"


# -------------------------------- LOAD FOLDER --------------------------------
load_folder <- function(folder_path) {
  
  files <- list.files(folder_path, pattern = "\\.txt$", full.names = TRUE)
  
  agencies <- list()
  officers <- list()
  plaintiffs <- list()
  causes <- list()
  misconduct <- list()
  locations <- list()
  summaries <- list()
  is_complaints <- list()
  error_count <- 0
  
  for (fp in files) {
    filename <- basename(fp)
    raw <- paste(readLines(fp, warn = FALSE), collapse = "\n")
    txt <- strip_fences(raw)
    
    data <- tryCatch(
      fromJSON(txt, simplifyVector = FALSE),
      error = function(e) {
        error_count <<- error_count + 1
        return(NULL)
      }
    )
    
    if (is.null(data)) next
    
    is_complaints <- c(
      is_complaints,
      list(list(
        filename = filename,
        is_complaint = as.character(data$is_complaint %||% NA)
      ))
    )
    
    agencies <- c(
      agencies,
      lapply(data$agencies %||% list(), function(x) {
        c(filename = filename, x)
      })
    )
    
    officers <- c(
      officers,
      lapply(data$officers %||% list(), function(x) {
        c(filename = filename, x)
      })
    )
    
    plaintiffs <- c(
      plaintiffs,
      lapply(data$plaintiffs %||% list(), function(x) {
        c(filename = filename, x)
      })
    )
    
    causes <- c(
      causes,
      lapply(data$causes_of_action %||% list(), function(x) {
        x <- lapply(x, function(v) {
          if (is.null(v) || length(v) == 0) NA_character_ else as.character(v)
        })
        c(filename = filename, x)
      })
    )
    
    tm <- data$types_of_misconduct
    if (!is.null(tm)) {
      if (is.list(tm)) {
        misconduct <- c(
          misconduct,
          lapply(tm, function(m) {
            list(filename = filename, misconduct_type = m)
          })
        )
      } else {
        misconduct <- c(
          misconduct,
          list(list(filename = filename, misconduct_type = tm))
        )
      }
    }
    
    loc <- data$incident_location
    if (!is.null(loc)) {
      if (is.list(loc)) {
        locations <- c(
          locations,
          lapply(loc, function(l) {
            list(filename = filename, location = l)
          })
        )
      } else {
        locations <- c(
          locations,
          list(list(filename = filename, location = loc))
        )
      }
    }
    
    summaries <- c(
      summaries,
      list(list(
        filename = filename,
        event_summary = data$event_summary
      ))
    )
  }
  
  list(
    agencies      = safe_rows(agencies),
    officers      = safe_rows(officers),
    plaintiffs    = safe_rows(plaintiffs),
    causes        = safe_rows(causes),
    misconduct    = safe_rows(misconduct),
    locations     = safe_rows(locations),
    summaries     = safe_rows(summaries),
    is_complaints = safe_rows(is_complaints),
    errors        = error_count
  )
}


# -------------------------------- PROCESS --------------------------------
openai <- load_folder(folder_openai)
openai <- lapply(openai, function(df) df %>% normalize_df() %>% apply_code())

agencies_openai_df   <- openai$agencies
officers_openai_df   <- openai$officers
plaintiffs_openai_df <- openai$plaintiffs
causes_openai_df     <- openai$causes
misconduct_openai_df <- openai$misconduct
locations_openai_df  <- openai$locations
is_complaint_df      <- openai$is_complaints


# -------------------------------- FILTER --------------------------------
true_complaints <- is_complaint_df %>%
  filter(is_complaint == "true") %>%
  pull(code)

filter_and_join <- function(df, codes) {
  df %>%
    filter(code %in% codes) %>%
    left_join(docs, by = "code") %>%
    group_by(case_id) %>%
    slice_max(order, n = 1) %>%
    ungroup()
}

agencies_openai_df   <- filter_and_join(agencies_openai_df, true_complaints)
officers_openai_df   <- filter_and_join(officers_openai_df, true_complaints)
plaintiffs_openai_df <- filter_and_join(plaintiffs_openai_df, true_complaints)
causes_openai_df     <- filter_and_join(causes_openai_df, true_complaints)
misconduct_openai_df <- filter_and_join(misconduct_openai_df, true_complaints)
locations_openai_df  <- filter_and_join(locations_openai_df, true_complaints)


# -------------------------------- WRITE --------------------------------
dir.create("data/clean_data/openai_data", recursive = TRUE, showWarnings = FALSE)

write_csv(agencies_openai_df,   "data/clean_data/openai_data/agencies_openai_df.csv")
write_csv(officers_openai_df,   "data/clean_data/openai_data/officers_openai_df.csv")
write_csv(plaintiffs_openai_df, "data/clean_data/openai_data/plaintiffs_openai_df.csv")
write_csv(causes_openai_df,     "data/clean_data/openai_data/causes_openai_df.csv")
write_csv(misconduct_openai_df, "data/clean_data/openai_data/misconduct_openai_df.csv")
write_csv(locations_openai_df,  "data/clean_data/openai_data/locations_openai_df.csv")