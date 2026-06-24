Tools for building brick-proof, reproducible data bundles. Resolves
open-data sources through CKAN package_show and package_search
endpoints, records and verifies provenance with SHA256 digests and
Wayback Machine snapshots, validates downloaded data against a pinned
schema, and falls back to schema-driven synthetic data when the real
source is unreachable. Run records are captured in a manifest plus a
plain-language summary so any result can be traced back to its inputs.
