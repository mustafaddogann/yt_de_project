# Snapshot history and publication

Status: Accepted for the reference implementation.

Retain original content addressed deliveries and Bronze checksums. Replace only selected Silver/fact partitions in transactions so corrections remove stale rows without damaging later dates. Replays use date/checksum delivery identity. A source observation date is required.

Consequence: document limitations explicitly and verify the relevant cloud behavior in DEV before deployment.
