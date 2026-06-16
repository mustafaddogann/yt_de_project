"""Shared helpers used by the YouTube ELT DAG."""
from __future__ import annotations

import os
import re

import pandas as pd
from airflow.providers.google.cloud.hooks.gcs import GCSHook

_COL_NORMALIZE = re.compile(r"[^a-z0-9]+")


def _normalize(col: str) -> str:
    col = _COL_NORMALIZE.sub("_", col.strip().lower()).strip("_")
    return col or "col"


def clean_csv(input_file: str, output_file: str, load_date: str) -> None:
    """Normalize column names to BigQuery-safe identifiers and stamp load_date."""
    df = pd.read_csv(input_file)
    df.columns = [_normalize(c) for c in df.columns]
    df = df.replace(r"^\s*$", pd.NA, regex=True)
    df["load_date"] = load_date
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    df.to_csv(output_file, index=False)


def local_to_gcs(file_name: str, bucket_name: str, key: str, remove_local: bool = False) -> None:
    GCSHook().upload(bucket_name=bucket_name, object_name=key, filename=file_name)
    if remove_local and os.path.isfile(file_name):
        os.remove(file_name)


def read_sql(path: str) -> str:
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()
