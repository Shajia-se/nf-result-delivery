# nf-result-delivery

Delivery packager module for your ChIP-seq workflow outputs.

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

Also generates:

- `08_Summary/final_summary.tsv` (template + auto-filled FRiP/contrast rows where available)
- `08_Summary/README_result_notes.md`

## Run on HPC

```bash
cd /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-result-delivery
nextflow run main.nf -profile hpc
```

## Optional

Set custom date tag:

```bash
nextflow run main.nf -profile hpc --delivery_tag 20260221
```

Set custom root paths if needed:

```bash
nextflow run main.nf -profile hpc \
  --pipelines_root /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines
```
