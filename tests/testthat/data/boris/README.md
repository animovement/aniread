# BORIS fixtures

## BORIS 9 exports (`aggregated/boris9/`, `tabular/boris9/`)

Exported with BORIS 9.15.0 (PyPI `boris-behav-obs` 9.15.0) from BORIS's own
test project, `tests/files/test.boris` (identical to `project/test.boris`
here). BORIS is GPL-3.0, so these files are too. They were written by BORIS's
export code, `export_events.export_aggregated_events()` and
`export_events.export_tabular_events()` (the functions behind "Export events"
in the GUI), run headless from Python with the GUI dialogs answered in code:
every subject and behaviour selected, and the time interval at the dialog's
default, "limit to events". The files are unedited, CRLF line endings
included.

- `aggregated/boris9/boris9_aggregated_observation2.tsv` and `.csv`:
  aggregated events of "observation #2", the observation the older
  `aggregated/test_export_aggregated_events_test_full_*.tsv` files export.
  It plays two media files, so `FPS (frame/s)` reads `25.000;25.000`.
- `aggregated/boris9/boris9_aggregated_modifiers.tsv`: aggregated events of
  the observation "modifiers", with a `Modifier #1` column.
- `tabular/boris9/boris9_tabular_observation1.tsv` and `.csv`: tabular
  events of "observation #1", the observation the older
  `tabular/test_export_events_tabular.*` files export.
- `tabular/boris9/boris9_tabular_modifiers.tsv`: tabular events of the
  observation "modifiers".

## Older layouts

Files that share their name with one in BORIS's `tests/files`, such as
`aggregated/test_export_aggregated_events_test_full_*.tsv`,
`tabular/test_export_events_tabular.*` and `project/*.boris`, were copied from
there (GPL-3.0). The exports among them use layouts from before BORIS 8 and are
kept to test that those still read. `aggregated/synthetic/` holds files written
for these tests in the current aggregated layout.
