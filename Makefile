# --- GCP infra ---
tf-init:
	terraform -chdir=./terraform init

infra-up:
	terraform -chdir=./terraform apply

infra-down:
	terraform -chdir=./terraform destroy

# --- Local Airflow stack ---
perms:
	mkdir -p logs temp && chmod -R 777 logs temp

up: perms
	docker compose --env-file .env up --build -d

down:
	docker compose --env-file .env down

logs:
	docker compose logs -f airflow-scheduler airflow-webserver

shw:
	docker exec -ti yt-de-airflow-webserver bash

shs:
	docker exec -ti yt-de-airflow-scheduler bash

# Credential-free quality checks
check:
	python -m ruff check dags scripts tests
	python -m ruff format --check dags scripts tests
	python -m pytest -q
	python scripts/validate_repository.py
	python -m sqlfluff lint sql --dialect bigquery

bootstrap:
	python scripts/bootstrap.py

# Set SNAPSHOT_DATE from the actual source observation, never from wall clock.
trigger:
	docker compose exec airflow-scheduler airflow dags trigger youtube_de_pipeline --conf '{"snapshot_date":"$(SNAPSHOT_DATE)"}'
