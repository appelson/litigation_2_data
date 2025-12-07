import pandas as pd
import numpy as np
import re
import nltk
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from sentence_transformers import SentenceTransformer
import hdbscan


# ------------------- LOAD DATA -----------------------
df = pd.read_csv("data/clean_data/openai_data/causes_openai_df.csv")

# ------------------- NORMALIZATION -----------------------
nltk.download("stopwords", quiet=True)
nltk.download("wordnet", quiet=True)

extra_stopwords = {
    "cause", "cited", "department", "due", "reason", "because",
    "incident", "related", "associated", "assoc", "for", "of"
}

stop_words = set(stopwords.words("english")) | extra_stopwords
lemm = WordNetLemmatizer()

synonym_map = {
    "assoc": "association",
    "associated": "association",
    "association": "association"
}

def normalize_cause(text):
    if not isinstance(text, str) or not text.strip():
        return ""
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    tokens = text.split()
    tokens = [lemm.lemmatize(t) for t in tokens if t not in stop_words]
    tokens = [synonym_map.get(t, t) for t in tokens]
    return " ".join(tokens)

df["cause_norm"] = df["cause_cited"].apply(normalize_cause)


# ------------------- EMBEDDINGS -----------------------
model = SentenceTransformer("all-MiniLM-L6-v2")

embeddings = model.encode(
    df["cause_norm"].tolist(),
    normalize_embeddings=True,
    show_progress_bar=True
)


# ------------------- HDBSCAN -----------------------
clusterer = hdbscan.HDBSCAN(
    min_cluster_size=4,
    min_samples=1,
    metric="euclidean",
    cluster_selection_method="eom",
    cluster_selection_epsilon=0.05,
    prediction_data=True
).fit(embeddings)

df["cluster_id"] = clusterer.labels_


# ------------------- CLUSTER LABELS -----------------------
def most_common(x):
    x = x.dropna()
    vc = x.value_counts()
    return vc.index[0] if len(vc) else ""

cluster_labels = (
    df[df["cluster_id"] != -1]
      .groupby("cluster_id")["cause_cited"]
      .agg(most_common)
      .rename("cluster_label")
)

df = df.merge(cluster_labels, on="cluster_id", how="left")
df.loc[df["cluster_id"] == -1, "cluster_label"] = "other"


# ------------------- SUMMARY -----------------------
print(df.groupby("cluster_id").size().sort_index())
print(cluster_labels.head())

cluster_summary = (
    df.groupby(["cluster_id", "cluster_label"])
      .size()
      .reset_index(name="count")
      .sort_values("count", ascending=False)
)

print(cluster_summary)
