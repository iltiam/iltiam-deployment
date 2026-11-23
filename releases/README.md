# Production releases

One manifest per production release, `vX.Y.Z.md`, written by `scripts/release.sh prepare X.Y.Z` and merged in the
release pull request. Never edit a merged manifest: a change is a new release. How releases, rollbacks and the
`prod-vX.Y.Z` git tags work: [Runbook 10](../docs/runbooks/10-production-release.md).

No release yet: production is not deployed (#36).
