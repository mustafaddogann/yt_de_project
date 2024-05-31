from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from datetime import datetime

default_args = {
    'owner': 'airflow',
    'start_date': datetime(2024, 5, 15),
}

dag = DAG(
    'test_dag',
    default_args=default_args,
    description='A simple test DAG',
    schedule_interval='@once',
)

start_task = DummyOperator(task_id='start_task', dag=dag)
end_task = DummyOperator(task_id='end_task', dag=dag)

start_task >> end_task