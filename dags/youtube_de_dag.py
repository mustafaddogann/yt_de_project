"""YouTube ELT pipeline: Kaggle CSV → GCS → BigQuery (bronze → silver → gold)."""
from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.models import Variable
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator

from utils.utils import clean_csv, local_to_gcs, read_sql

PROJECT = Variable.get("gcp_project_id")
BUCKET = Variable.get("gcs_landing_bucket")

DAGS_DIR = "/opt/airflow/dags"
SQL_DIR = "/opt/airflow/sql/bigquery"
RAW_CSV = "/opt/airflow/data/Global YouTube Statistics.csv"
CLEAN_CSV = "/opt/airflow/temp/cleaned_youtube_stats.csv"

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}

with DAG(
    dag_id="youtube_de_pipeline",
    description="Kaggle YouTube stats → GCS → BigQuery Bronze/Silver/Gold",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["bigquery", "gcs", "youtube"],
) as dag:

    clean = PythonOperator(
        task_id="clean_csv",
        python_callable=clean_csv,
        op_kwargs={"input_file": RAW_CSV, "output_file": CLEAN_CSV},
    )

    upload = PythonOperator(
        task_id="upload_to_gcs",
        python_callable=local_to_gcs,
        op_kwargs={
            "file_name": CLEAN_CSV,
            "bucket_name": BUCKET,
            "key": "raw/youtube_stats/{{ ds }}/cleaned_youtube_stats.csv",
            "remove_local": True,
        },
    )

    load_bronze = GCSToBigQueryOperator(
        task_id="load_bronze",
        bucket=BUCKET,
        source_objects=["raw/youtube_stats/{{ ds }}/cleaned_youtube_stats.csv"],
        destination_project_dataset_table=f"{PROJECT}.bronze.raw_youtube_stats${{{{ ds_nodash }}}}",
        source_format="CSV",
        skip_leading_rows=1,
        autodetect=True,
        write_disposition="WRITE_TRUNCATE",
        time_partitioning={"type": "DAY", "field": "load_date"},
    )

    # GCSToBigQueryOperator doesn't add load_date — patch it on after load.
    stamp_bronze = BigQueryInsertJobOperator(
        task_id="stamp_bronze_load_date",
        configuration={
            "query": {
                "query": (
                    f"UPDATE `{PROJECT}.bronze.raw_youtube_stats` "
                    "SET load_date = DATE('{{ ds }}') WHERE load_date IS NULL"
                ),
                "useLegacySql": False,
            }
        },
    )

    build_silver = BigQueryInsertJobOperator(
        task_id="build_silver",
        configuration={
            "query": {
                "query": read_sql(os.path.join(SQL_DIR, "silver_stg_channel.sql")),
                "useLegacySql": False,
            }
        },
        params={"project": PROJECT},
    )

    build_gold_dims = BigQueryInsertJobOperator(
        task_id="build_gold_dims",
        configuration={
            "query": {
                "query": read_sql(os.path.join(SQL_DIR, "gold_dims.sql")),
                "useLegacySql": False,
            }
        },
        params={"project": PROJECT},
    )

    build_gold_facts = BigQueryInsertJobOperator(
        task_id="build_gold_facts",
        configuration={
            "query": {
                "query": read_sql(os.path.join(SQL_DIR, "gold_facts.sql")),
                "useLegacySql": False,
            }
        },
        params={"project": PROJECT},
    )

    build_gold_marts = BigQueryInsertJobOperator(
        task_id="build_gold_marts",
        configuration={
            "query": {
                "query": read_sql(os.path.join(SQL_DIR, "gold_marts.sql")),
                "useLegacySql": False,
            }
        },
        params={"project": PROJECT},
    )

    clean >> upload >> load_bronze >> stamp_bronze >> build_silver
    build_silver >> build_gold_dims >> build_gold_facts >> build_gold_marts
