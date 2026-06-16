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
