# P0 Combat UX reconciliation

This branch reconciles only the still-useful, low-risk subset of PR #256 onto the current clean main.

Included in this first slice:
- four proprietary base actions for each of the four current Veilleurs;
- four proprietary base actions for each of the 24 enemy definitions;
- no generic `Frappe` or generic `Soin` action;
- captured/recruited enemies resolve the same base-action definition as their source enemy;
- rank availability and formation policy remain data-driven;
- validation is isolated from the obsolete tactical runtime v3/v4 chain.

Explicitly not restored from #256 in this slice:
- old global `main_v44 -> main_v50` UI chain;
- old tactical runtime v3/v4 files;
- obsolete CI reshaping from the divergent branch;
- duplicate formation logic already present in Combat Sandbox v50.

Next reconciliation target after this slice is validated: deterministic focus/inspection and non-destructive skill preview, adapted directly to the current Combat Sandbox stack rather than reviving the legacy UI chain.
