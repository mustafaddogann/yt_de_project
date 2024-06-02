# Set up cloud infrastructure
tf-init:
	terraform -chdir=./terraform init

infra-up:
	terraform -chdir=./terraform apply

infra-down:
	terraform -chdir=./terraform destroy

ssh-ec2:.
	terraform -chdir=./terraform output -raw private_key > private_key.pem && \
	chmod 600 private_key.pem && \
	ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) && \
	rm private_key.pem

setup-infra: tf-init
	terraform -chdir=./terraform apply

# Setup containers to run Airflow

docker-spin-up:
	docker compose --env-file env up airflow-init && \
	docker compose --env-file env up --build -d

perms:
	mkdir -p logs plugins temp kaggle tests migrations && sudo chmod -R u=rwx,g=rwx,o=rwx logs plugins temp dags tests kaggle migrations spectrum_tables

up: perms docker-spin-up

down:
	docker compose down

shw:
	docker exec -ti webserver bash


shs:
	docker exec -ti scheduler bash


####################################################################################################################
# Port forwarding to local machine

cloud-metabase:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o "IdentitiesOnly yes" -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) -N -f -L 3000:$$(terraform -chdir=./terraform output -raw ec2_public_dns):3000 && open http://localhost:3000 && rm private_key.pem

cloud-airflow:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o "IdentitiesOnly yes" -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) -N -f -L 8080:$$(terraform -chdir=./terraform output -raw ec2_public_dns):8080 && open http://localhost:8080 && rm private_key.pem


####################################################################################################################
# Create tables in Warehouse
spectrum-migration:
	./spectrum_migrate.sh
