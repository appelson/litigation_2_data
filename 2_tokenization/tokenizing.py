# ---------------------------- IMPORTING LIBRARIES -----------------------------
import pandas as pd
import spacy
import re
import os
import json
from tqdm import tqdm
import glob
import json
from collections import Counter

# --------------------------- SETTING UP NLP PARSER ----------------------------
nlp = spacy.load("en_core_web_sm") 
INPUT_FILE = "data/overview_data/filtered_texts.csv"
OUTPUT_DIR = "data/tokenized_json"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ------------------------------- LOADING DATA ---------------------------------
df = pd.read_csv(INPUT_FILE)
df = df.dropna(subset=["text_content"])

# ---------------------------- TOKENIZING EACH FILE ----------------------------

for _, row in tqdm(df.iterrows(), total=len(df), desc="Tokenizing"):
    file_id = str(row["file_id"])
    text = row["text_content"]

    # Skip if text is empty or not a string
    if not isinstance(text, str) or not text.strip():
        continue

    text = re.sub(r"\s+", " ", text.strip())

    try:
        doc = nlp(text)
    except Exception as e:
        continue

    tokens = []
    for i, token in enumerate(doc):
        if token.is_stop or token.is_punct:
            continue
        tokens.append({
            "token_id": i,
            "token": token.text,
            "lower": token.text.lower(),
            "lemma": token.lemma_,
            "pos": token.pos_,
            "tag": token.tag_,
            "dep": token.dep_,
            "is_alpha": token.is_alpha,
            "shape": token.shape_,
            "ent_type": token.ent_type_ if token.ent_type_ else None,
        })

    output = {
        "file_id": file_id,
        "n_tokens": len(tokens),
        "tokens": tokens
    }

    try:
        with open(f"{OUTPUT_DIR}/{file_id}.json", "w", encoding="utf-8") as f:
            json.dump(output, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"file_id {file_id} due to write error: {e}")
        continue
