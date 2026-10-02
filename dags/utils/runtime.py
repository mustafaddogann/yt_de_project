"""Runtime cloud adapters. Nothing here executes during DAG discovery."""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

from jinja2 import Environment, StrictUndefined

from utils.utils import inspect_source, run_key, snapshot_date


def settings() -> dict:
    project = os.environ.get("GCP_PROJECT_ID", "")
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,61}[a-z0-9]", project):
        raise ValueError("Set a valid GCP_PROJECT_ID")
    return {
        "project": project,
        "bucket": os.environ["GCS_LANDING_BUCKET"],
        "location": os.getenv("BQ_LOCATION", "US"),
        "sql": os.getenv("SQL_DIR", "/opt/airflow/sql/bigquery"),
        "contract": os.getenv("CONTRACT_PATH", "/opt/airflow/contracts/youtube.json"),
    }


def client(persona="transform"):
    from airflow.providers.google.cloud.hooks.bigquery import BigQueryHook

    conf = settings()
    identity = (
        os.getenv("INGESTION_SERVICE_ACCOUNT" if persona == "ingest" else "TRANSFORMATION_SERVICE_ACCOUNT") or None
    )
    return BigQueryHook(use_legacy_sql=False, location=conf["location"], impersonation_chain=identity).get_client(
        project_id=conf["project"], location=conf["location"]
    )


def query(sql, values=None, persona="transform", label="operation", run_id=None):
    from google.cloud import bigquery

    parameters = [bigquery.ScalarQueryParameter(k, t, v) for k, (t, v) in (values or {}).items()]
    job = client(persona).query(
        sql,
        job_config=bigquery.QueryJobConfig(
            query_parameters=parameters,
            labels={"pipeline": "youtube", "step": label[:63], **({"run": run_id[:63]} if run_id else {})},
            maximum_bytes_billed=int(os.getenv("MAXIMUM_BYTES_BILLED", "1000000000")),
        ),
    )
    job.result()
    return job


def render(name):
    conf = settings()
    return (
        Environment(undefined=StrictUndefined).from_string((Path(conf["sql"]) / name).read_text()).render(params=conf)
    )


def dq(run_id, name, expected, actual, passed, severity="HARD", details="", persona="transform"):
    project = settings()["project"]
    query(
        f"""INSERT INTO `{project}.ops.data_quality_result`
    VALUES (@run_id,@name,'youtube','VALIDATION',@expected,@actual,@status,@severity,CURRENT_TIMESTAMP(),@details)""",
        {
            k: ("STRING", str(v))
            for k, v in {
                "run_id": run_id,
                "name": name,
                "expected": expected,
                "actual": actual,
                "status": "PASS" if passed else "FAIL",
                "severity": severity,
                "details": details,
            }.items()
        },
        persona,
    )


def initialize(**context):
    from airflow.exceptions import AirflowSkipException

    conf = settings()
    dagrun = context["dag_run"]
    rid = run_key(dagrun.dag_id, dagrun.run_id)
    query(
        f"""MERGE `{conf["project"]}.ops.pipeline_run` t USING (SELECT @rid run_id) s ON t.run_id=s.run_id
    WHEN MATCHED THEN UPDATE SET status='RUNNING', ended_at=NULL, error_message=NULL
    WHEN NOT MATCHED THEN INSERT(run_id,pipeline_name,airflow_run_id,started_at,status)
    VALUES(@rid,'youtube_de_pipeline',@airflow_id,CURRENT_TIMESTAMP(),'STARTED')""",
        {"rid": ("STRING", rid), "airflow_id": ("STRING", dagrun.run_id)},
    )
    try:
        rows = list(
            query(
                f"SELECT * FROM `{conf['project']}.ops.pipeline_control` WHERE pipeline_name='youtube_de_pipeline'"
            ).result()
        )
        if len(rows) != 1:
            raise ValueError("Exactly one control entry required")
        control = dict(rows[0])
        if not control["is_active"]:
            raise AirflowSkipException("Pipeline disabled in control")
        if (
            control["load_type"] != "SNAPSHOT"
            or control["target_dataset"] != "bronze"
            or control["target_table"] != "raw_youtube_stats"
        ):
            raise ValueError("Unsupported control routing: this DAG implements one snapshot pipeline")
        if not control["data_quality_enabled"]:
            raise ValueError("Hard quality gates cannot be disabled")
        date_value = snapshot_date(dagrun.conf["snapshot_date"])
        query(
            f"UPDATE `{conf['project']}.ops.pipeline_run` SET snapshot_date=@date,status='RUNNING' WHERE run_id=@rid",
            {"date": ("DATE", date_value), "rid": ("STRING", rid)},
        )
        return {
            "run_id": rid,
            "snapshot_date": date_value,
            "source": control["source_location"],
            "source_system": control["source_name"],
            "allow_correction": dagrun.conf.get("allow_correction") is True,
        }
    except Exception as exc:
        query(
            f"UPDATE `{conf['project']}.ops.pipeline_run` SET status='FAILED',ended_at=CURRENT_TIMESTAMP(),error_message=@error WHERE run_id=@rid",
            {"error": ("STRING", str(exc)[:2000]), "rid": ("STRING", rid)},
        )
        raise


def prepare(meta):
    from google.cloud import bigquery

    conf = settings()
    try:
        result = inspect_source(meta["source"], conf["contract"])
    except Exception as exc:
        dq(meta["run_id"], "source_contract", "valid CSV", str(exc), False, persona="ingest")
        raise
    checksum = result["checksum"]
    previous = list(
        query(
            f"""SELECT source_checksum FROM `{conf["project"]}.ops.pipeline_snapshot`
        WHERE snapshot_date=@date""",
            {"date": ("DATE", meta["snapshot_date"])},
            "ingest",
        ).result()
    )
    if any(row.source_checksum != checksum for row in previous) and not meta["allow_correction"]:
        dq(
            meta["run_id"],
            "correction_authorization",
            "explicit allow_correction",
            "changed file",
            False,
            persona="ingest",
        )
        raise ValueError("Changed snapshot requires allow_correction=true")
    query(
        f"""UPDATE `{conf["project"]}.ops.pipeline_run` SET source_file=@file,source_checksum=@checksum,
        source_rows=@count,rejected_rows=@rejects WHERE run_id=@rid""",
        {
            "file": ("STRING", meta["source"]),
            "checksum": ("STRING", checksum),
            "count": ("INT64", result["source_count"]),
            "rejects": ("INT64", len(result["rejects"])),
            "rid": ("STRING", meta["run_id"]),
        },
        "ingest",
    )
    if result["rejects"]:
        table = f"{conf['project']}.ops.rejected_record"
        rejects = [dict(r, run_id=meta["run_id"], snapshot_date=meta["snapshot_date"]) for r in result["rejects"]]
        c = client("ingest")
        c.load_table_from_json(
            rejects, table, job_config=bigquery.LoadJobConfig(write_disposition="WRITE_APPEND")
        ).result()
    dq(
        meta["run_id"],
        "source_contract",
        "0 rejected rows",
        len(result["rejects"]),
        not result["rejects"],
        persona="ingest",
    )
    if result["rejects"]:
        raise ValueError("Rejected rows persisted; correct source before publishing")
    dq(
        meta["run_id"],
        "historical_correction",
        "unchanged delivery or authorized correction",
        "correction" if any(row.source_checksum != checksum for row in previous) else "new or replay",
        not any(row.source_checksum != checksum for row in previous),
        severity="WARNING",
        persona="ingest",
    )
    meta.update(checksum=checksum, expected_rows=len(result["rows"]))
    return meta


def load_bronze(meta):
    from google.api_core.exceptions import Conflict, NotFound, PreconditionFailed
    from google.cloud import bigquery
    from airflow.providers.google.cloud.hooks.gcs import GCSHook

    conf = settings()
    result = inspect_source(meta["source"], conf["contract"])
    if result["checksum"] != meta["checksum"]:
        raise ValueError("Source changed between validation and ingestion")
    identity = os.getenv("INGESTION_SERVICE_ACCOUNT") or None
    storage = GCSHook(impersonation_chain=identity).get_conn()
    raw_key = f"raw/youtube/{meta['snapshot_date']}/{meta['checksum']}/source.csv"
    blob = storage.bucket(conf["bucket"]).blob(raw_key)
    try:
        blob.upload_from_filename(meta["source"], if_generation_match=0)
    except (Conflict, PreconditionFailed):
        import hashlib

        if hashlib.sha256(blob.download_as_bytes()).hexdigest() != meta["checksum"]:
            raise ValueError("Existing immutable object checksum mismatch")
    params = {"date": ("DATE", meta["snapshot_date"]), "checksum": ("STRING", meta["checksum"])}
    exists = list(
        query(
            f"""SELECT COUNT(*) n FROM `{conf["project"]}.bronze.raw_youtube_stats`
        WHERE snapshot_date=@date AND source_checksum=@checksum""",
            params,
            "ingest",
        ).result()
    )[0].n
    if exists:
        if exists != meta["expected_rows"]:
            raise ValueError("Existing Bronze delivery has inconsistent count")
        return None
    now = datetime.now(timezone.utc).isoformat()
    records = [
        dict(
            {k: v for k, v in row.items()},
            run_id=meta["run_id"],
            source_file=f"gs://{conf['bucket']}/{raw_key}",
            source_system=meta["source_system"],
            source_checksum=meta["checksum"],
            ingestion_timestamp=now,
            snapshot_date=meta["snapshot_date"],
        )
        for row in result["rows"]
    ]
    # Explicit table schema is provisioned by bootstrap; scientific notation stays as source strings.
    schema = client("ingest").get_table(f"{conf['project']}.bronze.raw_youtube_stats").schema
    normalized_key = raw_key.replace("source.csv", "normalized.ndjson")
    normalized = "\n".join(json.dumps(row) for row in records)
    normalized_blob = storage.bucket(conf["bucket"]).blob(normalized_key)
    try:
        normalized_blob.upload_from_string(normalized, if_generation_match=0)
    except (Conflict, PreconditionFailed):
        pass  # First delivery owns its immutable metadata.
    job_id = "youtube_load_" + meta["snapshot_date"].replace("-", "") + "_" + meta["checksum"]
    c = client("ingest")
    for recovery in range(10):
        candidate = job_id if recovery == 0 else f"{job_id}_recovery_{recovery}"
        try:
            job = c.get_job(candidate)
        except NotFound:
            try:
                job = c.load_table_from_uri(
                    f"gs://{conf['bucket']}/{normalized_key}",
                    f"{conf['project']}.bronze.raw_youtube_stats",
                    job_id=candidate,
                    job_config=bigquery.LoadJobConfig(
                        schema=schema,
                        source_format="NEWLINE_DELIMITED_JSON",
                        write_disposition="WRITE_APPEND",
                        labels={"pipeline": "youtube", "run": meta["run_id"][:63]},
                    ),
                )
            except Conflict:
                job = c.get_job(candidate)
        if job.error_result:
            continue  # A terminal failed load is atomic and appended no records.
        job.result()  # Reattach running/succeeded jobs; never launch an ambiguous duplicate.
        return job
    raise ValueError("Ten terminal load failures; inspect IAM/source before further recovery")


def execute_stage(stage, **context):
    conf = settings()
    meta = context["ti"].xcom_pull(task_ids="initialize")
    if stage != "prepare_source":
        meta = context["ti"].xcom_pull(task_ids="prepare_source")
    if not meta:
        raise ValueError("Missing run metadata")
    persona = "ingest" if stage in ("prepare_source", "load_bronze") else "transform"
    attempt = context["ti"].try_number
    identity = {"rid": ("STRING", meta["run_id"]), "stage": ("STRING", stage), "attempt": ("INT64", attempt)}
    query(
        f"""INSERT INTO `{conf["project"]}.ops.pipeline_step_run`
      (run_id,step_name,attempt,started_at,status) VALUES(@rid,@stage,@attempt,CURRENT_TIMESTAMP(),'RUNNING')""",
        identity,
        persona,
    )
    job = None
    try:
        if stage == "prepare_source":
            output = prepare(meta)
        elif stage == "load_bronze":
            job = load_bronze(meta)
            output = None
        else:
            job = query(
                render(stage + ".sql"),
                {
                    "snapshot_date": ("DATE", meta["snapshot_date"]),
                    "checksum": ("STRING", meta["checksum"]),
                    "expected_rows": ("INT64", meta["expected_rows"]),
                },
                label=stage,
                run_id=meta["run_id"],
            )
            output = None
            if stage != "gold_marts":
                dq(meta["run_id"], stage + "_assertions", "all SQL assertions pass", "pass", True)
        if stage in ("load_bronze", "silver_stg_channel", "gold_facts"):
            layer = {"load_bronze": "bronze", "silver_stg_channel": "silver", "gold_facts": "gold"}[stage]
            query(
                f"UPDATE `{conf['project']}.ops.pipeline_run` SET {layer}_rows=@n WHERE run_id=@rid",
                {"rid": ("STRING", meta["run_id"]), "n": ("INT64", meta["expected_rows"])},
                persona,
            )
        query(
            f"""UPDATE `{conf["project"]}.ops.pipeline_step_run`
         SET status='SUCCEEDED',ended_at=CURRENT_TIMESTAMP(),job_id=@job,bytes_processed=@bytes,affected_rows=@affected
         WHERE run_id=@rid AND step_name=@stage AND attempt=@attempt""",
            dict(
                identity,
                job=("STRING", getattr(job, "job_id", None)),
                bytes=("INT64", getattr(job, "total_bytes_processed", None)),
                affected=("INT64", getattr(job, "num_dml_affected_rows", None)),
            ),
            persona,
        )
        return output
    except Exception as exc:
        query(
            f"""UPDATE `{conf["project"]}.ops.pipeline_step_run` SET status='FAILED',
          ended_at=CURRENT_TIMESTAMP(),error_message=@error WHERE run_id=@rid AND step_name=@stage AND attempt=@attempt""",
            dict(identity, error=("STRING", str(exc)[:2000])),
            persona,
        )
        if stage not in ("prepare_source", "load_bronze"):
            dq(meta["run_id"], stage + "_assertions", "successful execution", "failed", False, details=str(exc)[:2000])
        raise


def finalize(**context):
    from airflow.exceptions import AirflowException

    conf = settings()
    dagrun = context["dag_run"]
    rid = run_key(dagrun.dag_id, dagrun.run_id)
    states = {ti.task_id: ti.state for ti in dagrun.get_task_instances() if ti.task_id != "finalize"}
    failed = any(state in ("failed", "upstream_failed") for state in states.values())
    success = all(state == "success" for state in states.values())
    status = (
        "SUCCEEDED"
        if success
        else "PARTIAL"
        if failed and states.get("load_bronze") == "success"
        else "FAILED"
        if failed
        else "SKIPPED"
    )
    query(
        f"""UPDATE `{conf["project"]}.ops.pipeline_run` SET status=@status,ended_at=CURRENT_TIMESTAMP(),
      error_message=IF(@status IN ('FAILED','PARTIAL'),@error,error_message) WHERE run_id=@rid""",
        {"rid": ("STRING", rid), "status": ("STRING", status), "error": ("STRING", json.dumps(states))},
    )
    if failed:
        raise AirflowException("Pipeline failed; inspect ops.pipeline_step_run")
