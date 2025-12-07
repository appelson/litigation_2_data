# From Individual Claims to Systemic Patterns: Extracting a Dataset from Police Misconduct Litigation
---

This repository contains the full data-processing, extraction, and analysis pipeline associated with the paper **"From Individual Claims to Systemic Patterns: Extracting a Dataset from Police Misconduct Litigation."**

The paper investigates whether modern large language models, specifically a zero-shot GPT-4o-Mini pipeline, can convert federal police-misconduct complaints into structured data. This repository provides the code, processing workflow, and data schema used in the study. **Note:** The data we used are not included due to licensing restrictions, but a tiny is provided.

## Project Overview

Civil-rights complaints contain rich narrative accounts of interactions with law enforcement, yet no public dataset systematically identifies which agencies are sued or what harms are alleged. The accompanying paper evaluates LLM extraction performance on **13,657 complaints** across **7,552 terminated “police action” cases (2015–2025)** in the Ninth Circuit.

## Repository Structure

```text
├── 1_loading_data/        # Raw data ingestion and initial formatting
├── 2_tokenization/        # Python tokenization into structured JSON
├── 3_extraction/          # LLM extraction scripts + extraction prompt
├── 4_aggregation/         # Merge, clean, and standardize extracted fields
├── 5_validation/          # Evaluation metrics and error checks
├── 6_analysis/            # Scripts used to generate analytical outputs
├── annotate_app/          # Shiny app for human annotation & inspection
├── data/
│   ├── raw_data/          # Metadata + sample OCR text + sample PDFs
│   ├── extract/           # Model-generated extracted text
│   ├── clean_data/        # Cleaned CSVs from sample text
│   ├── sample_data/       # Associated sample data
│   └── tokenized_json/    # Structured tokenization outputs
└── README.md
```
