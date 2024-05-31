import os
import kaggle.api
from airflow.models import Variable
from airflow import DAG
from airflow.utils.dates import days_ago
from airflow.operators.python_operator import PythonOperator

# Retrieve Airflow variables for Kaggle credentials
# KAGGLE_USERNAME = Variable.get("KAGGLE_USERNAME")
# KAGGLE_KEY = Variable.get("KAGGLE_KEY")

# Define the name of the dataset on Kaggle
dataset_name = 'nelgiriyewithana/global-youtube-statistics-2023'

# Function to download Kaggle dataset and upload to S3
def import_kaggle_to_s3():
    # Authenticate with Kaggle using Airflow variables
    kaggle.api.authenticate()
    
    # Download dataset using Kaggle API
    kaggle.api.dataset_download_files(dataset_name, path='/data/kaggle_dataset', unzip=True)
    

# Define your Airflow DAG
dag = DAG(
    'kaggle_download_dag',
    schedule_interval='@daily',  # Adjust as needed
    start_date=days_ago(1),
    catchup=False  # Set to False if you don't want historical DAG runs
)

# Define a PythonOperator to execute the import_kaggle_to_s3 function
download_task = PythonOperator(
    task_id='download_kaggle_dataset',
    python_callable=import_kaggle_to_s3,
    dag=dag
)

# Set task dependencies if needed
# For example, if you have other tasks to run before or after this one:
# download_task.set_upstream(...)

