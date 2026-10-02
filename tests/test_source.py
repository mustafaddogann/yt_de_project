import csv
import json
from pathlib import Path

import pytest

from utils.utils import business_key, inspect_source, normalize, run_key, snapshot_date

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "contracts/youtube.json"


def source(tmp_path, overrides=None, duplicate=False):
    contract = json.loads(CONTRACT.read_text())
    row = dict.fromkeys(contract["columns"], "")
    row.update(youtuber="Example", subscribers="10", video_views="2.28E+11", uploads="1")
    row.update(overrides or {})
    path = tmp_path / "input.csv"
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(row))
        writer.writeheader()
        writer.writerow(row)
        if duplicate:
            writer.writerow(row)
    return path


def test_actual_source_contract():
    result = inspect_source(str(ROOT / "data/Global YouTube Statistics.csv"), str(CONTRACT))
    assert result["source_count"] == 995
    assert result["rejects"] == []


def test_normalization_and_keys():
    assert normalize("Gross tertiary education enrollment (%)") == "gross_tertiary_education_enrollment"
    assert business_key(" EXAMPLE ") == business_key("example")
    assert run_key("dag", "run") == run_key("dag", "run")
    assert run_key("dag", "run") != run_key("dag", "another")


@pytest.mark.parametrize("value", ["-1", "oops", "Infinity", "1.5", "1e40"])
def test_invalid_required_numeric_is_quarantined(tmp_path, value):
    result = inspect_source(str(source(tmp_path, {"subscribers": value})), str(CONTRACT))
    assert not result["rows"]
    assert len(result["rejects"]) == 1


def test_missing_key_is_rejected(tmp_path):
    result = inspect_source(str(source(tmp_path, {"youtuber": ""})), str(CONTRACT))
    assert "missing:youtuber" in result["rejects"][0]["reasons"]


def test_duplicate_detected_and_not_hidden(tmp_path):
    result = inspect_source(str(source(tmp_path, duplicate=True)), str(CONTRACT))
    assert len(result["rows"]) == 1
    assert "duplicate_business_key" in result["rejects"][0]["reasons"]
    assert result["source_count"] == 2


def test_replay_has_stable_checksum(tmp_path):
    path = source(tmp_path)
    assert inspect_source(str(path), str(CONTRACT)) == inspect_source(str(path), str(CONTRACT))


def test_breaking_schema(tmp_path):
    path = source(tmp_path, {"extra_column": "unexpected"})
    with pytest.raises(ValueError, match="Schema mismatch"):
        inspect_source(str(path), str(CONTRACT))


def test_empty_file(tmp_path):
    path = tmp_path / "empty.csv"
    path.write_text("")
    with pytest.raises(ValueError):
        inspect_source(str(path), str(CONTRACT))


def test_date_is_source_observation_not_execution():
    assert snapshot_date("2023-01-01") == "2023-01-01"
    with pytest.raises(ValueError):
        snapshot_date("2999-01-01")
    with pytest.raises(ValueError):
        snapshot_date("2023-02-30")
