#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

def delivery_tag = params.delivery_tag ?: new Date().format('yyyyMMdd')
def delivery_name = "final_delivery_${delivery_tag}"

def delivery_level = (params.delivery_level ?: 'lean').toString().toLowerCase()
if (!(delivery_level in ['lean', 'full'])) {
  exit 1, "ERROR: --delivery_level must be one of: lean, full"
}

process result_delivery {
  tag "delivery_${delivery_tag}_${delivery_level}"
  stageInMode 'symlink'
  stageOutMode 'move'

  publishDir "${params.project_folder}/${params.result_delivery_output}", mode: 'copy', overwrite: true

  output:
    path("${delivery_name}")

  script:
  """
  set -euo pipefail

  dest="${delivery_name}"
  level="${delivery_level}"

  mkdir -p "\$dest"/{01_QC_FRiP,02_Peaks_IDR,03_DiffBind,04_DeepTools,05_Motif_HOMER,06_Annotation_ChIPseeker,07_BrowserTracks,08_Summary,09_MultiQC}

  copy_if_exists() {
    local src="\$1"
    local dst="\$2"
    [[ -f "\$src" ]] && cp -f "\$src" "\$dst/" || true
  }

  copy_glob() {
    local pattern="\$1"
    local dst="\$2"
    shopt -s nullglob
    for f in \$pattern; do
      cp -f "\$f" "\$dst/"
    done
    shopt -u nullglob
  }

  # 01 FRiP
  copy_glob "${params.frip_out}/*.frip.tsv" "\$dest/01_QC_FRiP"

  # 02 IDR
  copy_glob "${params.idr_out}/*_idr.sorted.chr.narrowPeak" "\$dest/02_Peaks_IDR"
  copy_glob "${params.idr_out}/*_idr.txt" "\$dest/02_Peaks_IDR"
  copy_glob "${params.idr_out}/*_idr.log" "\$dest/02_Peaks_IDR"
  copy_glob "${params.idr_out}/*_idr.txt.png" "\$dest/02_Peaks_IDR"

  # 03 DiffBind
  copy_if_exists "${params.diffbind_out}/01_general_QC.pdf" "\$dest/03_DiffBind"
  copy_glob "${params.diffbind_out}/02_*.pdf" "\$dest/03_DiffBind"
  copy_glob "${params.diffbind_out}/significant.*.tsv" "\$dest/03_DiffBind"
  copy_glob "${params.diffbind_out}/all_peaks.*.tsv" "\$dest/03_DiffBind"
  copy_glob "${params.diffbind_out}/condition_unique_*.bed" "\$dest/03_DiffBind"
  copy_if_exists "${params.diffbind_out}/diffbind_summary.tsv" "\$dest/03_DiffBind"
  copy_if_exists "${params.diffbind_out}/peak_universe_upset_input.tsv" "\$dest/03_DiffBind"
  copy_if_exists "${params.diffbind_out}/peak_universe_condition_sizes.tsv" "\$dest/03_DiffBind"
  copy_if_exists "${params.diffbind_out}/peak_universe_pairwise_overlap.tsv" "\$dest/03_DiffBind"

  # 04 deepTools
  copy_glob "${params.deeptools_out}/*/*.heatmap.png" "\$dest/04_DeepTools"
  copy_glob "${params.deeptools_out}/*/*.heatmap.pdf" "\$dest/04_DeepTools"
  copy_glob "${params.deeptools_out}/*/*.profile.png" "\$dest/04_DeepTools"
  copy_glob "${params.deeptools_out}/*/*.profile.pdf" "\$dest/04_DeepTools"

  # full mode only: larger intermediate tables
  if [[ "\$level" == "full" ]]; then
    copy_glob "${params.deeptools_out}/*/*.matrix.tab" "\$dest/04_DeepTools"
  fi

  # 05 HOMER motif
  copy_glob "${params.homer_out}/motif/*_motifs/knownResults.txt" "\$dest/05_Motif_HOMER"
  copy_glob "${params.homer_out}/motif/*_motifs/homerResults.html" "\$dest/05_Motif_HOMER"
  copy_glob "${params.homer_out}/motif_compare/*_motifs/knownResults.txt" "\$dest/05_Motif_HOMER"
  copy_glob "${params.homer_out}/motif_compare/*_motifs/homerResults.html" "\$dest/05_Motif_HOMER"

  # 06 ChIPseeker
  copy_if_exists "${params.chipseeker_out}/annotated_master_table.tsv" "\$dest/06_Annotation_ChIPseeker"
  copy_if_exists "${params.chipseeker_out}/annotated_master_table.xlsx" "\$dest/06_Annotation_ChIPseeker"
  copy_if_exists "${params.chipseeker_out}/annotation_summary.by_sample.tsv" "\$dest/06_Annotation_ChIPseeker"
  copy_if_exists "${params.chipseeker_out}/annotation_summary.by_sample.pdf" "\$dest/06_Annotation_ChIPseeker"

  # 07 Browser tracks (full mode only; usually large)
  if [[ "\$level" == "full" ]]; then
    copy_glob "${params.bw_out}/*.bw" "\$dest/07_BrowserTracks"
  fi

  # 09 MultiQC
  copy_if_exists "${params.multiqc_out}/multiqc_report.html" "\$dest/09_MultiQC"

  # 08 Summary
  cat > "\$dest/08_Summary/qc_master_table.sample.tsv" << 'TSV'
sample_id	condition	replicate	library_type	is_control	control_id	raw_reads	mapped_reads	pct_mapped_reads	mapped_reads_dedup	pct_duplicates	unique_reads_mapq4	pct_reads_used_mapq4_of_raw	macs3_peaks_q0.1	macs3_peaks_q0.01	frip_idr	frip_consensus
TSV

  cat > "\$dest/08_Summary/qc_master_table.dictionary.tsv" << 'TSV'
column	description	source_module	source_file_or_logic
sample_id	Sample identifier from samples_master	nextflow-chipseq	samples_master.csv
condition	Biological condition from samples_master	nextflow-chipseq	samples_master.csv
replicate	Replicate identifier from samples_master	nextflow-chipseq	samples_master.csv
library_type	Library type from samples_master	nextflow-chipseq	samples_master.csv
is_control	Whether the row is a control/input sample	nextflow-chipseq	samples_master.csv
control_id	Matched control sample_id for ChIP sample	nextflow-chipseq	samples_master.csv
raw_reads	Total raw reads before filtering	nf-fastp	.fastp.json summary.before_filtering.total_reads
mapped_reads	Number of mapped reads before duplicate removal	nf-bwa	.bam.stat line: mapped
pct_mapped_reads	Percent mapped before duplicate removal	nf-bwa	.bam.stat line: mapped percent
mapped_reads_dedup	Number of mapped reads after duplicate removal	nf-picard + nf-result-delivery	samtools view -c -F 260 on .dedup.bam
pct_duplicates	Fraction of duplicate reads reported by Picard MarkDuplicates	nf-picard	.dedup.metrics.txt PERCENT_DUPLICATION x 100
unique_reads_mapq4	Reads retained in clean BAM after MAPQ>=4 and mito removal	nf-chipfilter + nf-result-delivery	samtools view -c -F 260 on .clean.bam
pct_reads_used_mapq4_of_raw	unique_reads_mapq4 divided by raw_reads x 100	nf-result-delivery	Computed during QC table build
macs3_peaks_q0.1	Peak count from MACS3 idr_q0.1 branch after peak-level blacklist filtering	nf-macs3	wc -l on idr_q0.1/<sample>_peaks.narrowPeak
macs3_peaks_q0.01	Peak count from MACS3 strict_q0.01 branch after peak-level blacklist filtering	nf-macs3	wc -l on strict_q0.01/<sample>_peaks.narrowPeak
frip_idr	FRiP using IDR peaks	nf-frip	<sample>.idr.frip.tsv FRiP column
frip_consensus	FRiP using peak-consensus peaks	nf-frip	<sample>.consensus.frip.tsv FRiP column
TSV

  python3 - <<'PY' > "\$dest/08_Summary/qc_master_table.sample.tsv.tmp"
import csv
import json
import os
import re
import subprocess
from pathlib import Path

samples_master = Path("${params.samples_master}")
fastp_out = Path("${params.fastp_out}")
bwa_out = Path("${params.bwa_out}")
picard_out = Path("${params.picard_out}")
chipfilter_out = Path("${params.chipfilter_out}")
macs3_out = Path("${params.macs3_out}")
frip_out = Path("${params.frip_out}")

header = [
    "sample_id", "condition", "replicate", "library_type", "is_control", "control_id",
    "raw_reads", "mapped_reads", "pct_mapped_reads", "mapped_reads_dedup", "pct_duplicates",
    "unique_reads_mapq4", "pct_reads_used_mapq4_of_raw", "macs3_peaks_q0.1", "macs3_peaks_q0.01",
    "frip_idr", "frip_consensus"
]
print("\t".join(header))

def read_fastp_raw_reads(sample_id):
    p = fastp_out / f"{sample_id}.fastp.json"
    if not p.exists():
        return ""
    try:
        with p.open() as fh:
            data = json.load(fh)
        return str(data.get("summary", {}).get("before_filtering", {}).get("total_reads", ""))
    except Exception:
        return ""

def read_bwa_mapping(sample_id):
    p = bwa_out / f"{sample_id}.bam.stat"
    mapped = ""
    pct = ""
    if not p.exists():
        return mapped, pct
    pat = re.compile(r"^(\\d+) \\+ \\d+ mapped \\(([-0-9.]+)%")
    for line in p.read_text().splitlines():
        m = pat.search(line)
        if m:
          mapped = m.group(1)
          pct = m.group(2)
          break
    return mapped, pct

def read_picard_dup_pct(sample_id):
    p = picard_out / f"{sample_id}.dedup.metrics.txt"
    if not p.exists():
        return ""
    lines = [ln.rstrip("\\n") for ln in p.read_text().splitlines()]
    header_idx = None
    for i, ln in enumerate(lines):
        if "PERCENT_DUPLICATION" in ln and not ln.startswith("#"):
            header_idx = i
            break
    if header_idx is None:
        return ""
    data_idx = None
    for j in range(header_idx + 1, len(lines)):
        ln = lines[j].strip()
        if ln and not ln.startswith("#"):
            data_idx = j
            break
    if data_idx is None:
        return ""
    cols = lines[header_idx].split("\\t")
    vals = lines[data_idx].split("\\t")
    try:
        idx = cols.index("PERCENT_DUPLICATION")
        val = vals[idx]
        return f"{float(val) * 100:.2f}"
    except Exception:
        return ""

def samtools_count(path_obj):
    if not path_obj.exists():
        return ""
    try:
        out = subprocess.check_output(
            ["samtools", "view", "-c", "-F", "260", str(path_obj)],
            text=True
        ).strip()
        return out
    except Exception:
        return ""

def resolve_first(prefix, suffix, directory):
    hits = sorted(directory.glob(f"{prefix}*{suffix}"))
    if not hits:
        return None
    exact = [p for p in hits if p.name == f"{prefix}{suffix}"]
    return exact[0] if exact else hits[0]

def line_count(path_obj):
    if not path_obj or not path_obj.exists():
        return ""
    try:
        with path_obj.open() as fh:
            return str(sum(1 for _ in fh))
    except Exception:
        return ""

def read_frip(sample_id, peak_set):
    p = frip_out / f"{sample_id}.{peak_set}.frip.tsv"
    if not p.exists():
        return ""
    rows = p.read_text().strip().splitlines()
    if len(rows) < 2:
        return ""
    vals = rows[1].split("\\t")
    return vals[6] if len(vals) > 6 else ""

with samples_master.open(newline="") as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        enabled = (row.get("enabled") or "").strip().lower()
        if enabled not in ("", "true"):
            continue

        sample_id = (row.get("sample_id") or "").strip()
        raw_reads = read_fastp_raw_reads(sample_id)
        mapped_reads, pct_mapped_reads = read_bwa_mapping(sample_id)
        mapped_reads_dedup = samtools_count(picard_out / f"{sample_id}.dedup.bam")
        pct_duplicates = read_picard_dup_pct(sample_id)
        unique_reads_mapq4 = samtools_count(chipfilter_out / f"{sample_id}.clean.bam")
        macs3_peaks_q01 = line_count(macs3_out / "strict_q0.01" / f"{sample_id}_peaks.narrowPeak")
        macs3_peaks_q10 = line_count(macs3_out / "idr_q0.1" / f"{sample_id}_peaks.narrowPeak")
        frip_idr = read_frip(sample_id, "idr")
        frip_consensus = read_frip(sample_id, "consensus")

        pct_reads_used = ""
        try:
            if raw_reads and unique_reads_mapq4:
                pct_reads_used = f"{(float(unique_reads_mapq4) / float(raw_reads)) * 100:.2f}"
        except Exception:
            pct_reads_used = ""

        out = [
            sample_id,
            (row.get("condition") or "").strip(),
            (row.get("replicate") or "").strip(),
            (row.get("library_type") or "").strip(),
            (row.get("is_control") or "").strip(),
            (row.get("control_id") or "").strip(),
            raw_reads,
            mapped_reads,
            pct_mapped_reads,
            mapped_reads_dedup,
            pct_duplicates,
            unique_reads_mapq4,
            pct_reads_used,
            macs3_peaks_q10,
            macs3_peaks_q01,
            frip_idr,
            frip_consensus,
        ]
        print("\\t".join(out))
PY

  cat "\$dest/08_Summary/qc_master_table.sample.tsv.tmp" >> "\$dest/08_Summary/qc_master_table.sample.tsv"
  rm -f "\$dest/08_Summary/qc_master_table.sample.tsv.tmp"

  cat > "\$dest/08_Summary/final_summary.tsv" << 'TSV'
level\tsample_or_group\tcondition\treplicate\tfrip\tidr_peak_count\tdiffbind_sig_count\tdiffbind_unique_up_count\tdiffbind_unique_down_count\ttop_motif_1\ttop_motif_2\ttop_annotation_1\ttop_annotation_2\tnotes
TSV

  shopt -s nullglob
  for f in ${params.frip_out}/*.frip.tsv; do
    sample=\$(awk 'NR==2{print \$1}' "\$f")
    frip=\$(awk 'NR==2{print \$6}' "\$f")
    cond="NA"
    [[ "\$sample" == WT* ]] && cond="WT"
    [[ "\$sample" == TG* ]] && cond="TG"
    printf "sample\t%s\t%s\tNA\t%s\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\t\n" "\$sample" "\$cond" "\$frip" >> "\$dest/08_Summary/final_summary.tsv"
  done
  shopt -u nullglob

  if [[ -f "${params.diffbind_out}/diffbind_summary.tsv" ]]; then
    awk 'NR>1{printf "contrast\t%s\tNA\tNA\tNA\tNA\t%s\t%s\t%s\tNA\tNA\tNA\tNA\tExploratory if batch confounded\\n",\$1,\$3,\$4,\$5}' \
      "${params.diffbind_out}/diffbind_summary.tsv" >> "\$dest/08_Summary/final_summary.tsv" || true
  fi

  cat > "\$dest/08_Summary/README_result_notes.md" << MD
# Final Delivery Notes

- Delivery level: ${delivery_level}
- `lean`: excludes large browser tracks (`.bw`) and deepTools matrix tables.
- `full`: includes browser tracks and deepTools matrix tables.
- If batch and condition are confounded, interpret differential results as exploratory.
MD

  cat > "\$dest/README.md" << 'MD'
# Final Delivery Package

This folder contains organized final deliverables:

- 01_QC_FRiP
- 02_Peaks_IDR
- 03_DiffBind
- 04_DeepTools
- 05_Motif_HOMER
- 06_Annotation_ChIPseeker
- 07_BrowserTracks
- 08_Summary
- 09_MultiQC
MD
  """
}

workflow {
  result_delivery()
}
