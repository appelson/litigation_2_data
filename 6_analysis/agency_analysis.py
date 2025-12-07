import re
import numpy as np
import pandas as pd
from itertools import combinations
from sentence_transformers import SentenceTransformer
import hdbscan
import networkx as nx

# ------------------- LOAD DATA -----------------------
agencies = pd.read_csv("data/clean_data/openai_data/agencies_openai_df.csv")

# ------------------- NORMALIZE NAMES -----------------------
def normalize_name(text: str) -> str:
    if not isinstance(text, str) or not text.strip():
        return ""
    text = text.lower()
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text)

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
        text = re.sub(p, " ", text)

    return re.sub(r"\s+", " ", text).strip()

agencies["normalized"] = agencies["agency_name"].fillna("").apply(normalize_name)

# ------------------- EMBEDDINGS -----------------------
model = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")

# ------------------- CATEGORY CLUSTERING -----------------------
def cluster_agency_group(df_group: pd.DataFrame) -> pd.DataFrame:
    df = df_group.copy()
    if len(df) < 2:
        df["cluster"] = -1
        return df
    embeddings = model.encode(df["normalized"].tolist(), show_progress_bar=False)
    clusterer = hdbscan.HDBSCAN(
        min_cluster_size=2,
        min_samples=1,
        metric="euclidean",
        cluster_selection_method="eom",
        cluster_selection_epsilon=0.15
    ).fit(embeddings)
    df["cluster"] = clusterer.labels_
    return df

clustered = (
    agencies
    .groupby("agency_category", group_keys=False)
    .apply(cluster_agency_group)
    .reset_index(drop=True)
)

# ------------------- GLOBAL CLUSTER IDS -----------------------
clustered = clustered.sort_values(["agency_category", "cluster", "normalized"])
clustered["global_cluster_id"] = clustered.groupby(
    ["agency_category", "cluster"]
).ngroup()

# ------------------- CLUSTER LABELS -----------------------
common_names = (
    clustered.groupby(["agency_category", "cluster"])["agency_name"]
    .agg(lambda s: s.value_counts().idxmax() if len(s.dropna()) else "")
    .rename("cluster_label")
)

clustered = clustered.merge(common_names, on=["agency_category", "cluster"], how="left")

clustered["cluster_label"] = (
    clustered["cluster_label"]
    .str.lower()
    .str.replace(r"[^a-z0-9 ]", " ", regex=True)
    .str.replace(r"\s+", " ", regex=True)
    .str.strip()
)

noise_mask = clustered["cluster"] == -1
clustered.loc[noise_mask, "cluster_label"] = (
    "other " + clustered.loc[noise_mask, "agency_category"].str.lower()
)

# ------------------- CLUSTER METADATA -----------------------
def normalize_name_simple(text: str) -> str:
    if not isinstance(text, str) or not text.strip():
        return ""
    text = re.sub(r"[^\w\s]", " ", text.lower())
    return re.sub(r"\s+", " ", text).strip()

cluster_modes = (
    clustered.groupby("global_cluster_id")["agency_name"]
    .agg(lambda x: x.mode().iat[0])
    .reset_index()
    .rename(columns={"agency_name": "most_common_name"})
)

cluster_meta = (
    cluster_modes
    .merge(
        clustered.groupby("global_cluster_id")["cluster"].first().rename("cluster_val"),
        on="global_cluster_id"
    )
    .merge(
        clustered.groupby("global_cluster_id")["agency_category"].first(),
        on="global_cluster_id"
    )
)

def representative_name(row):
    if row["cluster_val"] == -1:
        return f"other {normalize_name_simple(row['agency_category'])}"
    return normalize_name_simple(row["most_common_name"])

cluster_meta["clean_name"] = cluster_meta.apply(representative_name, axis=1)
cluster_name_map = dict(zip(cluster_meta["global_cluster_id"], cluster_meta["clean_name"]))

# ------------------- CATEGORY SUMMARY -----------------------
file_cat = (
    clustered.groupby(["filename", "agency_category"])["global_cluster_id"]
    .unique()
    .reset_index()
)

file_cat["rep_names"] = file_cat["global_cluster_id"].apply(
    lambda ids: "; ".join(sorted(cluster_name_map[cid] for cid in ids))
)

output = (
    file_cat
    .pivot(index="filename", columns="agency_category", values="rep_names")
    .reset_index()
)

print(output)

# ------------------- CLUSTER SIZE SUMMARY -----------------------
cluster_counts = (
    clustered.groupby("global_cluster_id")
    .size()
    .reset_index(name="count")
)

cluster_counts = cluster_counts.merge(
    cluster_meta[["global_cluster_id", "clean_name", "agency_category"]],
    on="global_cluster_id",
    how="left"
)

global_counts = cluster_counts.sort_values("count", ascending=False)
print(global_counts.head(20))

# ------------------- BUILD EDGES -----------------------
edges = []
for _, g in clustered.groupby("filename"):
    ids = sorted(g["global_cluster_id"].unique())
    edges.extend(combinations(ids, 2))

edge_df = (
    pd.DataFrame(edges, columns=["source", "target"])
    .groupby(["source", "target"])
    .size()
    .reset_index(name="weight")
)

edge_df["source_name"] = edge_df["source"].map(cluster_name_map)
edge_df["target_name"] = edge_df["target"].map(cluster_name_map)

# ------------------- GRAPH CENTRALITY -----------------------
G = nx.Graph()
for _, r in edge_df.iterrows():
    G.add_edge(r["source_name"], r["target_name"], weight=r["weight"])

degree = dict(G.degree(weight="weight"))
betweenness = nx.betweenness_centrality(G, weight="weight", normalized=True)
pagerank = nx.pagerank(G, weight="weight")

try:
    eigen = nx.eigenvector_centrality(G, weight="weight", max_iter=500)
except:
    eigen = {n: None for n in G.nodes()}

closeness = nx.closeness_centrality(G, distance=lambda u, v, e: 1/e["weight"])

importance_df = pd.DataFrame({
    "agency": list(G.nodes()),
    "weighted_degree": pd.Series(degree),
    "betweenness": pd.Series(betweenness),
    "pagerank": pd.Series(pagerank),
    "eigenvector": pd.Series(eigen),
    "closeness": pd.Series(closeness),
})
