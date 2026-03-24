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

- `08_Summary/qc_master_table.sample.tsv`
- `08_Summary/qc_master_table.dictionary.tsv`
- `08_Summary/peak_universe_matrix.<profile>.tsv`
- `08_Summary/peak_universe_matrix.dictionary.tsv`
- `08_Summary/README_result_notes.md`

## QC Master Table

`qc_master_table.sample.tsv` provides one row per enabled sample and collects core sample-level QC from upstream modules:

- sample metadata from `samples_master.csv`
- raw read count from `nf-fastp` (`.fastp.json`)
- mapped read count and mapping rate from `nf-bwa` (`.bam.stat`)
- duplicate percentage and deduplicated mapped read count from `nf-picard`
- retained unique read count after `MAPQ >= 4` filtering from `nf-chipfilter`
- MACS3 peak counts from:
  - `idr_q0.1`
  - `consensus_q0.05`
  - `strict_q0.01`
- FRiP values from:
  - `idr`
  - `consensus_q0.01`
  - `consensus_q0.05`

Missing values are written as `NA`, so it is clear when a metric is not available or not applicable (for example control/input samples do not have MACS3 peak counts or FRiP values).

`qc_master_table.dictionary.tsv` explains each column and where it comes from.

## Exploratory Peak Universe Matrix

`peak_universe_matrix.<profile>.tsv` is an exploratory matrix built from a broad peak universe:

- universe source: `nf-peak-consensus/peak_consensus_output/consensus_q0.05/universe_peaks.bed`
- sample-level raw counts: `bedtools multicov` on `nf-chipfilter/chipfilter_output/*.clean.bam`
- sample-level normalized values: CPM using `unique_reads_mapq4` as denominator
- condition-level `0/1` columns: derived from overlap with `<condition>_consensus.bed`
- annotation:
  - preferred: direct `ChIPseeker` annotation of `universe_q0.05`
  - fallback: overlap-based annotation transfer from `consensus_q0.05` annotated peaks

This table is intended for exploratory downstream work by collaborators. It is broader and more permissive than the strict consensus sets used for some primary analyses.

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
