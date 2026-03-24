# nf-result-delivery

Delivery packager module for ChIP-seq workflow outputs.

## What it does

Builds `final_delivery_<YYYYMMDD>` and now keeps only:

- `08_Summary`

Also generates:

- `08_Summary/qc_master_table.sample.tsv`
- `08_Summary/qc_master_table.dictionary.tsv`
- `08_Summary/peak_universe_matrix.consensus_first_universe_peaks.tsv`
- `08_Summary/peak_universe_matrix.union_first_universe_peaks.tsv`
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

`nf-result-delivery` now writes two exploratory matrices:

- `peak_universe_matrix.consensus_first_universe_peaks.tsv`
  - universe source: `nf-peak-consensus/peak_consensus_output/consensus_q0.05/consensus_first_universe_peaks.bed`
- `peak_universe_matrix.union_first_universe_peaks.tsv`
  - universe source: `nf-peak-consensus/peak_consensus_output/consensus_q0.05/union_first_universe_peaks.bed`

Common logic for both matrices:
- sample-level raw counts: `bedtools multicov` on `nf-chipfilter/chipfilter_output/*.clean.bam`
- sample-level normalized values: CPM using `unique_reads_mapq4` as denominator
- condition-level `0/1` columns: derived from overlap with `<condition>_consensus.bed`
- annotation:
  - preferred: direct `ChIPseeker` annotation of the matching universe BED
  - fallback: overlap-based annotation transfer from `consensus_q0.05` annotated peaks

These tables are intended for exploratory downstream work by collaborators. The `consensus_first` version is the default higher-confidence exploratory view; the `union_first` version is broader and more permissive.

## Delivery Levels

- `lean` (default): compact delivery package, excludes larger files (`.bw`, deepTools matrix tables)
- `full`: includes browser tracks (`.bw`) and deepTools matrix tables

This module now focuses on summary tables only. Earlier versions also copied selected downstream result files, but those folders were often incomplete or uneven across WT/TG and were therefore removed from the delivery package to keep the output clearer.

## Run on HPC

Default:

```bash
cd /ictstr01/groups/idc/projects/uhlenhaut/jiang/pipelines/nf-result-delivery
nextflow run main.nf -profile hpc
```

Optional custom tag:

```bash
nextflow run main.nf -profile hpc --delivery_tag 20260221
```
