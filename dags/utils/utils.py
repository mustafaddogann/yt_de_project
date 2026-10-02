"""Pure source validation helpers; cloud imports belong to runtime code."""

from __future__ import annotations
import csv
import hashlib
import json
import re
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path


def normalize(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")


def snapshot_date(value: str) -> str:
    parsed = date.fromisoformat(value)
    if parsed > date.today():
        raise ValueError("Snapshot cannot be in the future")
    return parsed.isoformat()


def business_key(value: str) -> str:
    return hashlib.sha256(value.strip().lower().encode()).hexdigest()


def run_key(dag_id: str, airflow_run_id: str) -> str:
    return hashlib.sha256(f"{dag_id}:{airflow_run_id}".encode()).hexdigest()


def inspect_source(path: str, contract_path: str) -> dict:
    contract = json.loads(Path(contract_path).read_text())
    raw = Path(path).read_bytes()
    checksum = hashlib.sha256(raw).hexdigest()
    with Path(path).open(encoding=contract["encoding"], newline="") as handle:
        reader = csv.DictReader(handle)
        headers = [normalize(x) for x in (reader.fieldnames or [])]
        if len(headers) != len(set(headers)):
            raise ValueError("Normalized column names collide")
        missing = set(contract["columns"]) - set(headers)
        unexpected = set(headers) - set(contract["columns"])
        if missing or unexpected:
            raise ValueError(f"Schema mismatch: missing={sorted(missing)}, unexpected={sorted(unexpected)}")
        rows, rejects, seen = [], [], set()
        for number, original in enumerate(reader, 2):
            if None in original or any(value is None for value in original.values()):
                raise ValueError(f"Malformed CSV row {number}")
            row = {
                normalize(k): ("" if v.strip().lower() in ("nan", "null") else v.strip()) for k, v in original.items()
            }
            reasons = []
            for column in contract["required"]:
                if row[column].lower() in ("", "nan", "null"):
                    reasons.append(f"missing:{column}")
            for column in contract["nonnegative"]:
                value = row[column]
                if value.lower() in ("", "nan", "null"):
                    row[column] = ""
                    continue
                try:
                    numeric = Decimal(value)
                    if not numeric.is_finite() or numeric < 0 or numeric > Decimal("1e29"):
                        reasons.append(f"invalid_numeric:{column}")
                    if column in ("subscribers", "video_views", "uploads") and numeric != numeric.to_integral_value():
                        reasons.append(f"fractional_count:{column}")
                except InvalidOperation:
                    reasons.append(f"invalid_numeric:{column}")
            for column in set(contract.get("numeric", [])) - set(contract["nonnegative"]):
                value = row[column]
                if not value:
                    continue
                try:
                    numeric = Decimal(value)
                    if not numeric.is_finite() or abs(numeric) > Decimal("1e29"):
                        reasons.append(f"invalid_numeric:{column}")
                except InvalidOperation:
                    reasons.append(f"invalid_numeric:{column}")
            key = business_key(row[contract["business_key"]])
            if key in seen:
                reasons.append("duplicate_business_key")
            if reasons:
                rejects.append({"row_number": number, "record_json": json.dumps(row), "reasons": ",".join(reasons)})
            else:
                seen.add(key)
                row["channel_key"] = key
                rows.append(row)
    total = len(rows) + len(rejects)
    if not contract["min_rows"] <= total <= contract["max_rows"]:
        raise ValueError(f"Row count outside contract: {total}")
    return {"rows": rows, "rejects": rejects, "source_count": total, "checksum": checksum}
