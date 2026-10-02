"""Offline SQL syntax, contract, Terraform syntax, Compose and accidental-secret checks."""

import ast
import json
import re
import subprocess
from pathlib import Path

import hcl2
import yaml
from jinja2 import Environment, StrictUndefined

root = Path(__file__).resolve().parents[1]
for directory in ("dags", "scripts", "tests"):
    for source in (root / directory).rglob("*.py"):
        ast.parse(source.read_text(), filename=str(source), feature_version=(3, 11))
contract = json.loads((root / "contracts/youtube.json").read_text())
assert set(contract["required"]) <= set(contract["columns"])
for path in (root / "sql").rglob("*.sql"):
    sql = (
        Environment(undefined=StrictUndefined).from_string(path.read_text()).render(params={"project": "test-project"})
    )
    assert "{{" not in sql  # Full BigQuery scripting is parsed separately by SQLFluff.
for path in (root / "terraform").rglob("*.tf"):
    with path.open() as handle:
        hcl2.load(handle)
assert yaml.safe_load((root / "docker-compose.yaml").read_text())["services"]["airflow-scheduler"]
paths = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=root, text=True
).splitlines()
for name in paths:
    path = root / name
    if not path.is_file() or path.suffix in (".zip", ".png"):
        continue
    assert not name.endswith((".tfstate", ".pem", ".key")), f"Sensitive file: {name}"
    assert name != ".env" and ".DS_Store" not in name
    content = path.read_text(errors="replace")
    for pattern in (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", r'"private_key"\s*:', r"AIza[0-9A-Za-z_-]{35}"):
        assert not re.search(pattern, content), f"Potential secret: {name}"
print("SQL, HCL, configuration and narrow secret-pattern checks passed")
