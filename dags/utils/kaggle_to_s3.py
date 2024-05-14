from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from datetime import datetime, timedelta
import kaggle
import boto3
import os
from airflow.models import Variable

# Define Airflow variables
BUCKET_NAME = Variable.get("BUCKET")
KAGGLE_USERNAME = Variable.get("KAGGLE_USERNAME")
KAGGLE_KEY = Variable.get("KAGGLE_KEY")

# Function to download Kaggle dataset and upload to S3
def import_kaggle_to_s3():
    dataset_name = 'global-youtube-statistics-2023'

    # Download dataset using Kaggle API
    kaggle.api.authenticate(username=KAGGLE_USERNAME, key=KAGGLE_KEY)
    kaggle.api.dataset_download_files(f'{KAGGLE_USERNAME}/{dataset_name}', path='/tmp/kaggle_dataset', unzip=True)

    # Upload dataset to S3
    s3_client = boto3.client('s3')
    s3_key = f'kaggle_datasets/{dataset_name}'

    for file in os.listdir('/tmp/kaggle_dataset'):
        file_path = os.path.join('/tmp/kaggle_dataset', file)
        s3_client.upload_file(file_path, BUCKET_NAME, f'{s3_key}/{file}')

# Define default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'start_date': datetime(2024, 5, 12),
    'depends_on_past': True,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

# Define the DAG
dag = DAG(
    'import_kaggle_to_s3',
    default_args=default_args,
    description='Import Kaggle Dataset to S3',
    schedule_interval="0 0 * * *",  # Runs daily at midnight UTC
    catchup=False  # Disable historical backfill
)

# Define the task
import_kaggle_to_s3_task = PythonOperator(
    task_id='import_kaggle_to_s3',
    python_callable=import_kaggle_to_s3,
    dag=dag,
)

# Set task dependencies (if needed)
# import_kaggle_to_s3_task >> [other_task]

