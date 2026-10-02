# Security

Public Kaggle records are public data. Synthetic Security Demonstration contacts are obviously fake, use example.com and a reserved fictional phone number. They are stored in security_demo, separate from analytical layers. Terraform creates masked_demo.masked_contacts and authorizes that individual view to read the restricted dataset. Analysts receive viewer access only to gold and masked_demo, not security_demo. The masked view hides name and phone and exposes only one email character and a fixed example.com suffix.

A masked view alone is not a security boundary: users must lack base-table permissions. Do not add project-wide dataViewer to analyst principals. The restricted dataset uses google_bigquery_dataset_access for authorized-view access; do not mix it with IAM policy/member resources on the same dataset. Validate access using a distinct analyst principal.

No key creation is prescribed. Local ADC stays outside git and is mounted read-only. Production uses workload identity and short-lived service-account impersonation; the local Airflow scheduler process can impersonate both identities, so this does not isolate malicious DAG code. Deployment credentials and administrator roles remain outside routine tasks. Terraform state is sensitive and excluded from git; use access-controlled remote state for real deployments. Existing accidentally published secrets must be revoked, not merely deleted.

Local development stack credentials and webserver secret are development defaults. It is not a secured public Airflow deployment. Credential-free CI includes only narrow signature checks, not a claim of comprehensive secret detection.
