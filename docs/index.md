# ILTIAM system documentation

Written from the system as built (iltiam-deployment#4). Start here:

- [System architecture](architecture.md): C4 context, containers and the backend's modules.
- [Integration guide](integration.md): apps ↔ backend, backend ↔ AI service, notifications, with sequence diagrams.
- [ADR index](adr-index.md): every architecture decision record, across all repositories.
- [SRS divergences](srs-divergences.md): every decision that differs from the SRS.
- [Runbooks](runbooks/01-oci-account-and-vm.md): setting up and running the platform, in order.
- [Secrets](secrets.md): every secret, its owner, rotation and revocation.

Build it locally: `pip install -r docs/requirements.txt && mkdocs build --strict` (or `mkdocs serve`).
