from pathlib import Path
from types import SimpleNamespace

import pytest
from jinja2 import Environment, StrictUndefined

from utils import runtime

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize("name", ["silver_stg_channel", "gold_facts"])
def test_sql_replacement_is_partition_scoped_and_atomic(name):
    sql = (ROOT / f"sql/bigquery/{name}.sql").read_text()
    assert "BEGIN TRANSACTION;" in sql and "COMMIT TRANSACTION;" in sql
    delete = next(line for line in sql.splitlines() if line.startswith("DELETE"))
    assert "WHERE snapshot_date=@snapshot_date" in delete
    assert "CREATE OR REPLACE TABLE" not in sql


def test_dimension_backfill_does_not_overwrite_newer_attributes():
    sql = (ROOT / "sql/bigquery/gold_dims.sql").read_text()
    assert sql.count("s.last_snapshot>=t.last_snapshot") == 2
    assert "ROW_NUMBER() OVER" in sql


def test_fact_foreign_keys_and_loss_checked_before_publication():
    sql = (ROOT / "sql/bigquery/gold_facts.sql").read_text()
    assert sql.index("Unresolved fact foreign keys") < sql.index("BEGIN TRANSACTION")
    assert "dim_date" in sql and "dim_country" in sql and "dim_category" in sql
    assert "Fact row loss" in sql


def test_all_sql_templates_render():
    for path in (ROOT / "sql").rglob("*.sql"):
        rendered = (
            Environment(undefined=StrictUndefined)
            .from_string(path.read_text())
            .render(params={"project": "test-project"})
        )
        assert "{{" not in rendered


def test_stage_failure_is_audited_and_propagates(monkeypatch):
    calls = []
    monkeypatch.setattr(runtime, "settings", lambda: {"project": "test-project"})
    monkeypatch.setattr(
        runtime, "query", lambda sql, values=None, persona="transform", **kw: calls.append((sql, values))
    )
    monkeypatch.setattr(runtime, "prepare", lambda meta: (_ for _ in ()).throw(ValueError("bad source")))
    context = {"ti": SimpleNamespace(try_number=2, xcom_pull=lambda **kw: {"run_id": "rid"})}
    with pytest.raises(ValueError, match="bad source"):
        runtime.execute_stage("prepare_source", **context)
    assert "'RUNNING'" in calls[0][0]
    assert "status='FAILED'" in calls[-1][0]
    assert calls[-1][1]["attempt"] == ("INT64", 2)


def test_stage_success_records_job_and_counts(monkeypatch):
    calls = []
    monkeypatch.setattr(runtime, "settings", lambda: {"project": "test-project"})
    monkeypatch.setattr(
        runtime, "query", lambda sql, values=None, persona="transform", **kw: calls.append((sql, values))
    )
    monkeypatch.setattr(runtime, "load_bronze", lambda meta: SimpleNamespace(job_id="job123", total_bytes_processed=9))
    meta = {"run_id": "rid", "expected_rows": 3}
    context = {"ti": SimpleNamespace(try_number=1, xcom_pull=lambda **kw: meta)}
    runtime.execute_stage("load_bronze", **context)
    assert calls[1][1]["n"] == ("INT64", 3)
    assert calls[-1][1]["job"] == ("STRING", "job123")
    assert "status='SUCCEEDED'" in calls[-1][0]


@pytest.mark.parametrize("existing_count", [2, 0])
def test_bronze_replay_and_failed_job_recovery(monkeypatch, existing_count):
    import sys
    import types

    class NotFound(Exception):
        pass

    class Conflict(Exception):
        pass

    class PreconditionFailed(Exception):
        pass

    def module(name, **attrs):
        fake = types.ModuleType(name)
        fake.__dict__.update(attrs)
        monkeypatch.setitem(sys.modules, name, fake)
        return fake

    exceptions = module(
        "google.api_core.exceptions", NotFound=NotFound, Conflict=Conflict, PreconditionFailed=PreconditionFailed
    )
    module("google.api_core", exceptions=exceptions)
    bq = module("google.cloud.bigquery", LoadJobConfig=lambda **kw: kw)
    module("google.cloud", bigquery=bq)
    module("google")
    blob = SimpleNamespace(upload_from_filename=lambda *args, **kw: None, upload_from_string=lambda *args, **kw: None)
    storage = SimpleNamespace(bucket=lambda name: SimpleNamespace(blob=lambda name: blob))
    module("airflow.providers.google.cloud.hooks.gcs", GCSHook=lambda **kw: SimpleNamespace(get_conn=lambda: storage))
    monkeypatch.setattr(
        runtime, "settings", lambda: {"project": "test-project", "bucket": "bucket", "contract": "contract"}
    )
    monkeypatch.setattr(
        runtime, "inspect_source", lambda *args: {"checksum": "abc", "rows": [{"youtuber": "A"}, {"youtuber": "B"}]}
    )
    monkeypatch.setattr(
        runtime, "query", lambda *args, **kw: SimpleNamespace(result=lambda: [SimpleNamespace(n=existing_count)])
    )
    jobs, loaded = {}, []
    base = "youtube_load_20230801_abc"
    jobs[base] = SimpleNamespace(error_result={"reason": "backendError"})

    def get_job(identity):
        if identity not in jobs:
            raise NotFound()
        return jobs[identity]

    def load(uri, table, job_id, job_config):
        loaded.append(job_id)
        job = SimpleNamespace(error_result=None, job_id=job_id, result=lambda: None)
        jobs[job_id] = job
        return job

    c = SimpleNamespace(get_table=lambda name: SimpleNamespace(schema=[]), get_job=get_job, load_table_from_uri=load)
    monkeypatch.setattr(runtime, "client", lambda *args: c)
    meta = {
        "source": "input",
        "checksum": "abc",
        "snapshot_date": "2023-08-01",
        "expected_rows": 2,
        "run_id": "rid",
        "source_system": "source",
    }
    runtime.load_bronze(meta)
    runtime.load_bronze(meta)
    if existing_count:
        assert loaded == []
    else:
        # A confirmed failed job permits one recovery; another call reattaches that same job.
        assert loaded == [base + "_recovery_1"]


@pytest.mark.parametrize(
    "incoming,allowed,should_fail", [("abc", False, False), ("def", False, True), ("def", True, False)]
)
def test_correction_uses_published_checksum(monkeypatch, incoming, allowed, should_fail):
    import sys
    import types

    cloud = types.ModuleType("google.cloud")
    cloud.bigquery = SimpleNamespace()
    monkeypatch.setitem(sys.modules, "google.cloud", cloud)
    monkeypatch.setitem(sys.modules, "google", types.ModuleType("google"))
    monkeypatch.setattr(runtime, "settings", lambda: {"project": "test-project", "contract": "contract"})
    monkeypatch.setattr(
        runtime, "inspect_source", lambda *args: {"checksum": incoming, "rows": [{}], "rejects": [], "source_count": 1}
    )
    queries = []

    def query(sql, *args, **kw):
        queries.append(sql)
        return SimpleNamespace(result=lambda: [SimpleNamespace(source_checksum="abc")])

    monkeypatch.setattr(runtime, "query", query)
    monkeypatch.setattr(runtime, "dq", lambda *args, **kw: None)
    meta = {"run_id": "rid", "source": "file", "snapshot_date": "2023-08-01", "allow_correction": allowed}
    if should_fail:
        with pytest.raises(ValueError, match="allow_correction"):
            runtime.prepare(meta)
    else:
        assert runtime.prepare(meta)["checksum"] == incoming
    assert "ops.pipeline_snapshot" in queries[0]
