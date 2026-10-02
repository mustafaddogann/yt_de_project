"""Administrator-only schema initialization; never run inside the ingestion task."""

import os
from pathlib import Path

from google.cloud import bigquery
from jinja2 import Environment, StrictUndefined

project = os.environ["GCP_PROJECT_ID"]
client = bigquery.Client(project=project, location=os.getenv("BQ_LOCATION", "US"))
sql = (
    Environment(undefined=StrictUndefined)
    .from_string(Path("sql/bigquery/bootstrap.sql").read_text())
    .render(params={"project": project})
)
client.query(sql).result()
print("Initialized operational and Bronze schema")
