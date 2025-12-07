library(jsonlite)
library(dplyr)
library(stringr)
library(purrr)
library(tibble)
library(tidyr)

`%||%` <- function(x, y) if (is.null(x)) y else x

# ----------- UTIL FUNCS -----------
strip_fences <- function(txt) {
  txt |>
    str_trim() |>
    sub("^```[A-Za-z0-9]*\\s*\n", "", x = _) |>
    sub("\n?```$", "", x = _) |>
    str_trim()
}

extract_code <- function(filename) sub("_.*$", "", filename)

safe_as_char <- function(x) {
  if (is.null(x) || length(x) == 0) NA_character_ else as.character(x)
}

# ----------- LOAD FOLDER -----------
load_folder <- function(folder_path) {
  files <- list.files(folder_path, pattern = "\\.(json|txt)$", full.names = TRUE)
  
  out <- list(
    agencies = list(), officers = list(), plaintiffs = list(),
    causes = list(), misconduct = list(), locations = list(), summaries = list()
  )
  
  error_count <- 0
  
  for (fp in files) {
    filename <- basename(fp)
    txt <- strip_fences(paste(readLines(fp, warn = FALSE), collapse = "\n"))
    
    data <- tryCatch(fromJSON(txt, simplifyVector = FALSE), error = \(e) {
      error_count <<- error_count + 1
      NULL
    })
    if (is.null(data)) next
    
    out$agencies   <- c(out$agencies,   lapply(data$agencies %||% list(),   \(x) c(filename = filename, lapply(x, safe_as_char))))
    out$officers   <- c(out$officers,   lapply(data$officers %||% list(),   \(x) c(filename = filename, lapply(x, safe_as_char))))
    out$plaintiffs <- c(out$plaintiffs, lapply(data$plaintiffs %||% list(), \(x) c(filename = filename, lapply(x, safe_as_char))))
    out$causes     <- c(out$causes,     lapply(data$causes_of_action %||% list(), \(x) c(filename = filename, lapply(x, safe_as_char))))
    
    tm <- data$types_of_misconduct
    if (!is.null(tm)) {
      items <- if (is.list(tm)) tm else list(tm)
      out$misconduct <- c(out$misconduct,
                          lapply(items, \(m) list(filename = filename, misconduct_type = safe_as_char(m))))
    }
    
    loc <- data$incident_location
    if (!is.null(loc)) {
      items <- if (is.list(loc)) loc else list(loc)
      out$locations <- c(out$locations,
                         lapply(items, \(l) list(filename = filename, location = safe_as_char(l))))
    }
    
    out$summaries <- c(out$summaries, list(list(
      filename = filename, event_summary = safe_as_char(data$event_summary)
    )))
  }
  
  list(
    agencies   = bind_rows(out$agencies),
    officers   = bind_rows(out$officers),
    plaintiffs = bind_rows(out$plaintiffs),
    causes     = bind_rows(out$causes),
    misconduct = bind_rows(out$misconduct),
    locations  = bind_rows(out$locations),
    errors     = error_count
  )
}

# ----------- NORMALIZATION -----------
normalize_text <- function(x) {
  x |> as.character() |>
    str_to_lower() |>
    str_replace_all("[\u2018\u2019]", "'") |>
    str_replace_all("[\u201C\u201D]", "\"") |>
    str_replace_all("[[:cntrl:]]", " ") |>
    str_replace_all("\\s+", " ") |>
    str_trim()
}

normalize_df <- function(df) df |> mutate(across(where(is.character), normalize_text))
apply_code   <- function(df) df |> mutate(code = extract_code(filename))

# ----------- LOAD HUMAN -----------
human_raw <- load_folder("data/extract/sample_extracted_text")

human_list <- list(
  agencies_df    = human_raw$agencies,
  officers_df    = human_raw$officers,
  plaintiffs_df  = human_raw$plaintiffs,
  causes_df      = human_raw$causes,
  misconduct_df  = human_raw$misconduct,
  locations_df   = human_raw$locations
) |> map(\(df) df |> normalize_df() |> apply_code())

# ----------- LOAD OPENAI -----------
openai_list <- list(
  agencies_openai_df   = read_csv("data/clean_data/openai_data/agencies_openai_df.csv"),
  officers_openai_df   = read_csv("data/clean_data/openai_data/officers_openai_df.csv"),
  plaintiffs_openai_df = read_csv("data/clean_data/openai_data/plaintiffs_openai_df.csv"),
  causes_openai_df     = read_csv("data/clean_data/openai_data/causes_openai_df.csv"),
  misconduct_openai_df = read_csv("data/clean_data/openai_data/misconduct_openai_df.csv"),
  locations_openai_df  = read_csv("data/clean_data/openai_data/locations_openai_df.csv")
) |> map(\(df) df |> normalize_df() |> apply_code())

# ----------- FILTER MATCHED DOCS -----------
human_codes  <- unique(unlist(lapply(human_list, `[[`, "code")))
openai_codes <- unique(unlist(lapply(openai_list, `[[`, "code")))
codes_in_both <- intersect(human_codes, openai_codes)

filter_codes <- \(df) df |> filter(code %in% codes_in_both)

human_list  <- map(human_list, filter_codes)
openai_list <- map(openai_list, filter_codes)

# ----------- F1 HELPERS -----------
compute_f1 <- function(h, o, by_cols) {
  TP <- nrow(inner_join(o, h, by = by_cols))
  FP <- nrow(anti_join(o, h, by = by_cols))
  FN <- nrow(anti_join(h, o, by = by_cols))
  
  precision <- ifelse(TP + FP == 0, NA, TP / (TP + FP))
  recall    <- ifelse(TP + FN == 0, NA, TP / (TP + FN))
  f1        <- ifelse(is.na(precision) || is.na(recall) || (precision + recall == 0),
                      NA, 2 * precision * recall / (precision + recall))
  
  tibble(TP, FP, FN, precision, recall, f1)
}

per_document_f1 <- function(h, o, by_cols) {
  codes <- sort(unique(c(h$code, o$code)))
  map_dfr(codes, \(cd) {
    compute_f1(filter(h, code == cd), filter(o, code == cd), by_cols) |> mutate(code = cd)
  })
}

# ----------- ENTITY EVAL -----------

hc <- human_list$causes_df |> mutate(across(everything(), safe_as_char)) |> distinct(code, cause_number, cause_cited)
oc <- openai_list$causes_openai_df |> mutate(across(everything(), safe_as_char)) |> distinct(code, cause_number, cause_cited)
causes_results <- per_document_f1(hc, oc, c("code", "cause_number", "cause_cited"))

ha <- human_list$agencies_df |> distinct(code, agency_name, agency_category)
oa <- openai_list$agencies_openai_df |> distinct(code, agency_name, agency_category)
agency_results <- per_document_f1(ha, oa, c("code", "agency_name", "agency_category"))

hp <- human_list$plaintiffs_df |> distinct(code, plaintiff_name)
op <- openai_list$plaintiffs_openai_df |> distinct(code, plaintiff_name)
plaintiff_results <- per_document_f1(hp, op, c("code", "plaintiff_name"))

ho <- human_list$officers_df |> distinct(code, officer_name, agency_affiliation)
oo <- openai_list$officers_openai_df |> distinct(code, officer_name, agency_affiliation)
officer_results <- per_document_f1(ho, oo, c("code", "officer_name", "agency_affiliation"))

split_items <- \(x) {
  if (is.null(x) || is.na(x)) character()
  x |> str_split(";") |> unlist() |> normalize_text() |> discard(~ .x == "")
}

hm <- human_list$misconduct_df |> mutate(parts = map(misconduct_type, split_items)) |> unnest(parts) |> distinct(code, misconduct = parts)
om <- openai_list$misconduct_openai_df |> mutate(parts = map(misconduct_type, split_items)) |> unnest(parts) |> distinct(code, misconduct = parts)
misconduct_results <- per_document_f1(hm, om, c("code", "misconduct"))

hl <- human_list$locations_df |> mutate(parts = map(location, split_items)) |> unnest(parts) |> distinct(code, location = parts)
ol <- openai_list$locations_openai_df |> mutate(parts = map(location, split_items)) |> unnest(parts) |> distinct(code, location = parts)
location_results <- per_document_f1(hl, ol, c("code", "location"))

# ----------- SUMMARY -----------
strict_avg <- function(df) {
  df |>
    mutate(across(c(precision, recall, f1), ~ replace_na(.x, 0))) |>
    summarise(
      strict_precision = mean(precision),
      strict_recall    = mean(recall),
      strict_f1        = mean(f1),
      n = n()
    )
}

all_results_table <- bind_rows(
  causes     = strict_avg(causes_results),
  agencies   = strict_avg(agency_results),
  plaintiffs = strict_avg(plaintiff_results),
  misconduct = strict_avg(misconduct_results),
  locations  = strict_avg(location_results),
  officers   = strict_avg(officer_results),
  .id = "category"
)

dir.create("data/clean_data/sample_data", showWarnings = FALSE, recursive = TRUE)

walk2(
  human_list,
  names(human_list),
  \(df, name) {
    write_csv(df, file.path("data/clean_data/sample_data", paste0(name, ".csv")))
  }
)

write_csv(all_results_table, "5_validation/results.csv")