# RBAC

| Persona | Permissions |
| :--- | :--- |
| Ingestion runtime | Project jobUser; Bronze and ops dataEditor; landing objectCreator and objectViewer |
| Transformation runtime | Project jobUser; Bronze dataViewer; Silver, Gold and ops dataEditor |
| Analyst | Project jobUser; Gold and masked_demo dataViewer |
| Platform administrator | Explicit optional deployment principals with BigQuery/storage administrator privileges |
| Airflow orchestrator | TokenCreator on the two runtime service accounts only |

Terraform creates runtime identities. Principal lists are supplied via uncommitted variables; examples contain no real identities. Routine tasks do not use administrator roles. Dataset dataEditor is a pragmatic coarse grant for this reference project and allows audit mutation and table management within that dataset; it is not an append-only audit security model. The ingestion account cannot edit Silver/Gold, and transformation cannot upload source objects.

Set INGESTION_SERVICE_ACCOUNT and TRANSFORMATION_SERVICE_ACCOUNT to Terraform runtime outputs. Grant the actual ADC/workload principal impersonation through orchestrator_members. Enable iamcredentials.googleapis.com alongside BigQuery, Storage, IAM and Resource Manager APIs. Development mode omits impersonation and uses the ADC principal; use the union of scoped runtime permissions, not project Owner. Deployment/bootstrap requires a separate administrator session.

At enterprise scale, separate projects, isolated workers, custom minimal roles, protected audit storage and managed secret/workload identity services can strengthen boundaries. Those are not implemented here.
