"""Real Airflow import check, run in the pinned Docker image by CI."""

import os
import sys

os.environ["AIRFLOW__CORE__LOAD_EXAMPLES"] = "False"
sys.path.insert(0, "/opt/airflow/dags")
from airflow.models import DagBag
from unittest.mock import patch

with patch("airflow.models.Variable.get", side_effect=AssertionError("Parse-time Variable access")):
    bag = DagBag(dag_folder="/opt/airflow/dags", include_examples=False)
assert not bag.import_errors, bag.import_errors
dag = bag.get_dag("youtube_de_pipeline")
assert dag.max_active_runs == 1 and dag.schedule_interval is None
assert len(dag.tasks) == 8
assert dag.get_task("finalize").trigger_rule == "all_done"
assert len(dag.get_task("finalize").upstream_task_ids) == 7
print("Real Airflow DAG import and finalization topology passed")
