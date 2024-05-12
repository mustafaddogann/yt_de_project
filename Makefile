# Set up cloud infrastructure
tf-init:
	terraform -chdir=./terraform init

infra-up:
	terraform -chdir=./terraform apply

infra-down:
	terraform -chdir=./terraform destroy

ssh-ec2:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && \
	chmod 600 private_key.pem && \
	ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) && \
	rm private_key.pem

# Main target that combines infrastructure setup and key retrieval
setup-infra: tf-init
	terraform -chdir=./terraform apply

docker-spin-up:
	docker compose --env-file env up airflow-init && \
	docker compose --env-file env up --build -d

perms:
	mkdir -p logs plugins temp && \
	chmod -R u=rwx,g=rwx,o=rwx logs plugins temp  # Avoid using sudo in Makefile targets if possible

up: perms docker-spin-up
