import pandas as pd
import numpy as np
import re
from sentence_transformers import SentenceTransformer
import hdbscan

# ------------------- LOAD DATA -----------------------
officers = pd.read_csv("data/clean_data/openai_data/officers_openai_df.csv")

# ------------------- NORMALIZATION -----------------------

def normalize_agency(x):
    if not isinstance(x, str) or not x.strip():
        return ""
    x = x.lower()
    x = re.sub(r"[^\w\s]", " ", x)
    x = re.sub(r"\s+", " ", x)

    remove_patterns = [
        r"\bpolice department\b", r"\bpolice dept\b", r"\bpd\b", r"\bpolice\b",
        r"\bsheriff'?s office\b", r"\bsheriff'?s dept\b", r"\bsheriff'?s department\b",
        r"\bsheriff\b", r"\bso\b",
        r"\bdepartment of\b", r"\bdept of\b", r"\bdept\b",
        r"\bdistrict attorney\b", r"\bstate attorney\b", r"\battorney'?s office\b", r"\bda\b",
        r"\bhighway patrol\b", r"\bhp\b", r"\bstate patrol\b", r"\bpatrol\b",
        r"\bcounty of\b", r"\bcity of\b", r"\bthe county of\b",
        r"\bcounty\b", r"\bcity\b", r"\bstate\b"
    ]
    for p in remove_patterns:
        x = re.sub(p, " ", x)

    return re.sub(r"\s+", " ", x).strip()

def normalize_name(x):
    if not isinstance(x, str) or not x.strip():
        return ""
    x = x.lower()
    x = re.sub(r"[^\w\s]", " ", x)
    return re.sub(r"\s+", " ", x).strip()

officers["agency_norm"] = officers["agency_affiliation"].fillna("").apply(normalize_agency)
officers["name_norm"]   = officers["officer_name"].fillna("").apply(normalize_name)

# ------------------- MODEL -----------------------
model = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")

# ------------------- HDBSCAN HELPERS -----------------------

def run_hdbscan(texts, eps=0.25, min_cluster_size=2):
    emb = model.encode(texts, show_progress_bar=False)
    clusterer = hdbscan.HDBSCAN(
        min_samples=1,
        min_cluster_size=min_cluster_size,
        metric="euclidean",
        cluster_selection_method="eom",
        cluster_selection_epsilon=eps,
        prediction_data=True
    ).fit(emb)
    return clusterer.labels_, emb

def most_common(x):
    x = x.dropna()
    vc = x.value_counts()
    return vc.index[0] if len(vc) else ""

# ------------------- CLUSTER AGENCIES -----------------------
officers["agency_cluster"], agency_emb = run_hdbscan(
    officers["agency_norm"].tolist(),
    eps=0.30,
    min_cluster_size=2
)

agency_labels = (
    officers[officers["agency_cluster"] != -1]
        .groupby("agency_cluster")["agency_affiliation"]
        .agg(most_common)
        .rename("agency_cluster_label")
)

officers = officers.merge(agency_labels, on="agency_cluster", how="left")
officers.loc[officers["agency_cluster"] == -1, "agency_cluster_label"] = "other"

# ------------------- CLUSTER NAMES WITHIN AGENCY -----------------------

def cluster_names(group):
    labels, emb = run_hdbscan(
        group["name_norm"].tolist(),
        eps=0.10,
        min_cluster_size=2
    )
    group["name_cluster"] = labels
    return group

officers = (
    officers
        .groupby("agency_cluster", group_keys=False)
        .apply(cluster_names)
        .reset_index(drop=True)
)

name_labels = (
    officers[officers["name_cluster"] != -1]
        .groupby(["agency_cluster", "name_cluster"])["officer_name"]
        .agg(most_common)
        .rename("name_cluster_label")
)

officers = officers.merge(name_labels, on=["agency_cluster", "name_cluster"], how="left")
officers.loc[officers["name_cluster"] == -1, "name_cluster_label"] = "other"

# ------------------- FINAL PAIR COUNTS -----------------------
pair_counts = (
    officers
        .groupby(["officer_name", "agency_affiliation"])
        .size()
        .reset_index(name="count")
        .sort_values("count", ascending=False)
)
