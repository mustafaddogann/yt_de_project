"""Manual source snapshots; no cloud I/O during DAG import."""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.trigger_rule import TriggerRule

from utils.runtime import execute_stage, finalize, initialize

with DAG(
    "youtube_de_pipeline",
    description="Audited GCS and BigQuery snapshot ELT",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    default_args={"owner": "platform", "retries": 1, "retry_delay": timedelta(minutes=2)},
    tags=["youtube", "gcp", "snapshots"],
) as dag:
    start = PythonOperator(task_id="initialize", python_callable=initialize)
    previous = start
    for stage in ("prepare_source", "load_bronze", "silver_stg_channel", "gold_dims", "gold_facts", "gold_marts"):
        task = PythonOperator(task_id=stage, python_callable=execute_stage, op_kwargs={"stage": stage})
        previous >> task
        previous = task
    end = PythonOperator(task_id="finalize", python_callable=finalize, trigger_rule=TriggerRule.ALL_DONE)
    # Every task is a direct upstream so finalization observes all terminal states.
    for task in list(dag.tasks):
        if task != end:
            task >> end
