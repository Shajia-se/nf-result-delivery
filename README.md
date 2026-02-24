# nf-result-delivery

Delivery packager module for ChIP-seq workflow outputs.

## What it does

Builds `final_delivery_<YYYYMMDD>` and organizes outputs into:

- `01_QC_FRiP`
- `02_Peaks_IDR`
- `03_DiffBind`
- `04_DeepTools`
- `05_Motif_HOMER`
- `06_Annotation_ChIPseeker`
- `07_BrowserTracks`
- `08_Summary`
- `09_MultiQC`

Also generates:

- `08_Summary/final_summary.tsv`
- `08_Summary/README_result_notes.md`

## Delivery Levels

- `lean` (default): compact delivery package, excludes larger files (`.bw`, deepTools matrix tables)
- `full`: includes browser tracks (`.bw`) and deepTools matrix tables

This module copies selected files into a clean final folder (not symlink mode), so package size depends on included file types.

## Run on HPC

Default (lean, no extra parameter required):

```bash
cd /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-result-delivery
nextflow run main.nf -profile hpc
```

Full package:

```bash
nextflow run main.nf -profile hpc --delivery_level full
```

Optional custom tag:

```bash
nextflow run main.nf -profile hpc --delivery_tag 20260221
```
