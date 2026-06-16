# GCP setup

One-time commands to provision the BigQuery datasets, GCS bucket, and a
service account the DAG uses for auth.

## 1. Create the project

```bash
gcloud projects create yt-de-project --set-as-default
gcloud config set project yt-de-project
```

You'll need a billing account linked even though this stays inside the
free tier. BigQuery: 1 TB query / month + 10 GB storage free, GCS: 5 GB
free in `US` multi-region.

## 2. Enable APIs

```bash
gcloud services enable \
  bigquery.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com
```

## 3. Service account + key

```bash
gcloud iam service-accounts create yt-de-sa \
  --display-name "YouTube DE Pipeline SA"

SA=yt-de-sa@$(gcloud config get-value project).iam.gserviceaccount.com

gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
  --member="serviceAccount:${SA}" --role="roles/bigquery.admin" --condition=None
gcloud projects add-iam-policy-binding $(gcloud config get-value project) \
  --member="serviceAccount:${SA}" --role="roles/storage.admin" --condition=None

mkdir -p ~/.config/gcp
gcloud iam service-accounts keys create ~/.config/gcp/yt-de-sa.json \
  --iam-account="${SA}"
```

Point `GCP_SA_KEY_PATH` in `.env` at that file.

## 4. Provision the datasets and bucket

```bash
cd terraform
terraform init
terraform apply \
  -var "project_id=$(gcloud config get-value project)" \
  -var "bucket_name=yt-de-raw-$(gcloud config get-value project)"
```

This creates `bronze`, `silver`, `gold` datasets and the GCS bucket. Tear
down with `terraform destroy` — nothing here costs anything to leave
running, but it's a good habit.
