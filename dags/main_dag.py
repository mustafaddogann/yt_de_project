from datetime import datetime, timedelta

from utils.utils import _local_to_s3, run_redshift_external_query, clean_csv


from airflow import DAG
from airflow.contrib.operators.emr_add_steps_operator import (
    EmrAddStepsOperator,
)
from airflow.contrib.sensors.emr_step_sensor import EmrStepSensor
from airflow.models import Variable
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.postgres_operator import PostgresOperator
from airflow.operators.python import PythonOperator

# Config
BUCKET_NAME = Variable.get("BUCKET")
EMR_ID = Variable.get("EMR_ID")
EMR_STEPS = {}


# DAG definition
default_args = {
    "owner": "airflow",
    "depends_on_past": True,
    "wait_for_downstream": True,
    "start_date": datetime(2024, 5, 23),
    "email": ["airflow@airflow.com"],
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=1),
}

dag = DAG(
    "youtubers_data",
    default_args=default_args,
    schedule_interval="0 0 * * *",
    max_active_runs=1,
)
clean_csv_task = PythonOperator(
    dag=dag,
    task_id='clean_csv',
    python_callable=clean_csv,
    op_args=['/opt/airflow/data/Global YouTube Statistics.csv', '/opt/airflow/temp/Cleaned_Global_YouTube_Statistics.csv'],
)

pg_database_setup = PostgresOperator(
    dag=dag,
    task_id= "import_csv_data_to_pg",
    sql = "./scripts/sql/kaggle_pgsetup.sql",
    postgres_conn_id="postgres_default",
    depends_on_past=True,
    wait_for_downstream=True,

)

extract_top_1000_youtubers_data = PostgresOperator(
    dag=dag,
    task_id="extract_top_1000_youtubers_data",
    sql="./scripts/sql/unload_top_1000_youtubers.sql",
    postgres_conn_id="postgres_default",
    params={"top_1000_youtubers": "/temp/top_1000_youtubers.csv"},
    depends_on_past=True,
    wait_for_downstream=True,
)

top_1000_youtubers_to_stage_data_lake = PythonOperator(
    dag=dag,
    task_id="top_1000_youtubers_to_stage_data_lake",
    python_callable=_local_to_s3,
    op_kwargs={
        "file_name": "/opt/airflow/temp/top_1000_youtubers.csv",
        "key": "stage/top_1000_youtubers/{{ ds }}/top_1000_youtubers.csv",
        # "bucket_name": BUCKET_NAME,
        "bucket_name" : "yt-de-data-lake-20240602070509510300000003",
        "remove_local": "true",
    },
)

top_1000_youtubers_stage_data_lake_to_stage_tbl = PythonOperator(
    dag=dag,
    task_id="top_1000_youtubers_stage_data_lake_to_stage_tbl",
    python_callable=run_redshift_external_query,
    op_kwargs={
        "qry": "alter table spectrum.top_1000_youtubers_staging add \
            if not exists partition(insert_date='{{ ds }}') \
            location 's3://"
        + BUCKET_NAME
        + "/stage/top_1000_youtubers/{{ ds }}'",
    },
)


clean_csv_task >> pg_database_setup >> extract_top_1000_youtubers_data>>top_1000_youtubers_to_stage_data_lake >> top_1000_youtubers_stage_data_lake_to_stage_tbl