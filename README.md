# From Individual Claims to Systemic Patterns: Extracting a Dataset from Police Misconduct Litigation

**Elijah Appelson** — Stanford University — [appelson@stanford.edu](mailto:appelson@stanford.edu)  
**Zooey Carter Wilkinson** — Stanford University — [zooeycw@stanford.edu](mailto:zooeycw@stanford.edu)

---

This repository contains the full data-processing, extraction, and analysis pipeline associated with the paper **"From Individual Claims to Systemic Patterns: Extracting a Dataset from Police Misconduct Litigation."**

The paper investigates whether modern large language models—specifically a zero-shot GPT-4o-Mini pipeline—can convert federal police-misconduct complaints into structured data identifying:

* Law-enforcement agencies
* Individual officers
* Plaintiffs and demographic attributes
* Misconduct allegations
* Locations of incidents
* Causes of action

This repository provides the code, processing workflow, and data schema used in the study.

> **Note:** Raw complaint PDFs are not included due to licensing restrictions, but complete sample inputs and outputs are provided.

## 🧩 Project Overview

Civil-rights complaints contain rich narrative accounts of interactions with law enforcement, yet no public dataset systematically identifies which agencies are sued or what harms are alleged. The accompanying paper evaluates LLM extraction performance on **13,657 complaints** across **7,552 terminated “police action” cases (2015–2025)** in Lex Machina’s Ninth Circuit dataset.

This repository includes:

* OCR and text-preparation scripts
* Tokenization pipeline
* Zero-shot GPT-4o-Mini extraction workflow
* Cleaning and normalization code
* Clustering to consolidate agency and officer variants
* Validation and accuracy checks
* Analysis scripts used in the paper

It is meant to make the study reproducible, transparent, and extensible.

## 📁 Repository Structure

```text
litigation_2_data/
├── 1_loading_data/        # Raw data ingestion and initial formatting
├── 2_tokenization/        # Python tokenization into structured JSON
├── 3_extraction/          # LLM extraction scripts + extraction prompt
├── 4_aggregation/         # Merge, clean, and standardize extracted fields
├── 5_validation/          # Evaluation metrics and error checks
├── 6_analysis/            # Scripts used to generate analytical outputs
├── annotate_app/          # Shiny app for human annotation & inspection
├── data/
│   ├── raw_data/          # (No PDFs included) Metadata + OCR text
│   ├── extract/           # Model-generated extracted text
│   ├── clean_data/        # Cleaned CSVs used in the paper
│   ├── sample_data/       # Small demo dataset for reproducibility
│   └── tokenized_json/    # Structured tokenization outputs
└── README.md
```
