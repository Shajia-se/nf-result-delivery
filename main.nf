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
mapped_reads_dedup	Number of mapped reads after duplicate removal	nf-picard	<sample>.picard_qc.stats.tsv mapped_reads_postdup
pct_duplicates	Fraction of duplicate reads reported by Picard MarkDuplicates	nf-picard	<sample>.picard_qc.stats.tsv pct_duplicates
unique_reads_mapq4	Reads retained in clean BAM after MAPQ>=4 and mito removal	nf-chipfilter	<sample>.chipfilter.stats.tsv clean_reads
pct_reads_used_mapq4_of_raw	unique_reads_mapq4 divided by raw_reads x 100	nf-chipfilter + nf-result-delivery	Computed from chipfilter.stats.tsv clean_reads and fastp raw_reads
macs3_peaks_q0.1	Peak count from MACS3 idr_q0.1 branch after peak-level blacklist filtering	nf-macs3	wc -l on idr_q0.1/<sample>_peaks.narrowPeak
macs3_peaks_q0.05	Peak count from MACS3 relaxed consensus q0.05 branch after peak-level blacklist filtering	nf-macs3	wc -l on consensus_q0.05/<sample>_peaks.narrowPeak
macs3_peaks_q0.01	Peak count from MACS3 strict_q0.01 branch after peak-level blacklist filtering	nf-macs3	wc -l on strict_q0.01/<sample>_peaks.narrowPeak
frip_idr	FRiP using IDR peaks	nf-frip	<sample>.idr.frip.tsv FRiP column
frip_consensus_q0.01	FRiP using strict_q0.01 consensus peaks	nf-frip	<sample>.consensus_q0.01.frip.tsv FRiP column
frip_consensus_q0.05	FRiP using consensus_q0.05 peaks	nf-frip	<sample>.consensus_q0.05.frip.tsv FRiP column
TSV

  cat > "\$dest/08_Summary/peak_universe_matrix.dictionary.tsv" << TSV
column	description	source_module	source_file_or_logic
peak_id	Peak universe row identifier	nf-result-delivery	Sequential ID PU_1..PU_n
chr	Chromosome of universe peak	nf-peak-consensus	${params.peak_consensus_out}/${params.exploratory_universe_profile}/universe_peaks.bed
start	0-based start coordinate of universe peak	nf-peak-consensus	universe_peaks.bed
end	1-based end coordinate of universe peak	nf-peak-consensus	universe_peaks.bed
length	Peak width in bp	nf-result-delivery	end - start
<condition>	Condition-level presence/absence from normalized signal	nf-result-delivery	1 if any sample in condition has CPM >= ${params.exploratory_presence_cpm_threshold}, else 0
raw_<sample>	Raw fragment/read count in universe peak for sample	nf-result-delivery	bedtools multicov on chipfilter_output/<sample>.clean.bam
cpm_<sample>	Counts per million normalized by unique_reads_mapq4	nf-result-delivery	raw_<sample> / unique_reads_mapq4 * 1e6
annotation	Peak annotation label	nf-chipseeker / nf-result-delivery	Preferred from universe_q0.05 annotation, fallback from overlapping consensus_q0.05 annotation
gene_id	Nearest/annotated gene identifier	nf-chipseeker / nf-result-delivery	Preferred from universe_q0.05 annotation, fallback from overlapping consensus_q0.05 annotation
gene_name	Nearest/annotated gene symbol	nf-chipseeker / nf-result-delivery	Preferred from universe_q0.05 annotation, fallback from overlapping consensus_q0.05 annotation
distance_to_tss	Distance from peak to TSS when available	nf-chipseeker / nf-result-delivery	Preferred from universe_q0.05 annotation, fallback from overlapping consensus_q0.05 annotation
annotation_source	Where annotation row came from	nf-result-delivery	universe_q0.05 direct or consensus_q0.05 overlap fallback
TSV

  python3 - <<'PY' > "\$dest/08_Summary/qc_master_table.sample.tsv.tmp"
import csv
import json
import re
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
    "unique_reads_mapq4", "pct_reads_used_mapq4_of_raw", "macs3_peaks_q0.1", "macs3_peaks_q0.05", "macs3_peaks_q0.01",
    "frip_idr", "frip_consensus_q0.01", "frip_consensus_q0.05"
]
print("\\t".join(header))
def na(x):
    return "NA" if x in ("", None) else str(x)

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

def read_chipfilter_stats(sample_id):
    p = chipfilter_out / f"{sample_id}.chipfilter.stats.tsv"
    if not p.exists():
        return "", ""
    rows = p.read_text().strip().splitlines()
    if len(rows) < 2:
        return "", ""
    vals = rows[1].split("\\t")
    clean_reads = vals[3] if len(vals) > 3 else ""
    pct_retained = vals[4] if len(vals) > 4 else ""
    return clean_reads, pct_retained

def read_picard_stats(sample_id):
    p = picard_out / f"{sample_id}.picard_qc.stats.tsv"
    if not p.exists():
        return "", ""
    rows = p.read_text().strip().splitlines()
    if len(rows) < 2:
        return "", ""
    vals = rows[1].split("\\t")
    mapped = vals[2] if len(vals) > 2 else ""
    pctdup = vals[3] if len(vals) > 3 else ""
    return mapped, pctdup

with samples_master.open(newline="") as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        enabled = (row.get("enabled") or "").strip().lower()
        if enabled not in ("", "true"):
            continue

        sample_id = (row.get("sample_id") or "").strip()
        is_control = (row.get("is_control") or "").strip().lower() == "true"
        raw_reads = read_fastp_raw_reads(sample_id)
        mapped_reads, pct_mapped_reads = read_bwa_mapping(sample_id)
        mapped_reads_dedup, pct_duplicates = read_picard_stats(sample_id)
        unique_reads_mapq4, pct_retained_after_mito = read_chipfilter_stats(sample_id)
        macs3_peaks_q01 = line_count(macs3_out / "strict_q0.01" / f"{sample_id}_peaks.narrowPeak")
        macs3_peaks_q05 = line_count(macs3_out / "consensus_q0.05" / f"{sample_id}_peaks.narrowPeak")
        macs3_peaks_q10 = line_count(macs3_out / "idr_q0.1" / f"{sample_id}_peaks.narrowPeak")
        frip_idr = read_frip(sample_id, "idr")
        frip_consensus_q001 = read_frip(sample_id, "consensus_q0.01")
        if not frip_consensus_q001:
            frip_consensus_q001 = read_frip(sample_id, "consensus")
        frip_consensus_q005 = read_frip(sample_id, "consensus_q0.05")

        pct_reads_used = ""
        try:
            if raw_reads and unique_reads_mapq4:
                pct_reads_used = f"{(float(unique_reads_mapq4) / float(raw_reads)) * 100:.2f}"
        except Exception:
            pct_reads_used = ""

        if is_control:
            macs3_peaks_q10 = ""
            macs3_peaks_q05 = ""
            macs3_peaks_q01 = ""
            frip_idr = ""
            frip_consensus_q001 = ""
            frip_consensus_q005 = ""

        out = [
            na(sample_id),
            na((row.get("condition") or "").strip()),
            na((row.get("replicate") or "").strip()),
            na((row.get("library_type") or "").strip()),
            na((row.get("is_control") or "").strip()),
            na((row.get("control_id") or "").strip()),
            na(raw_reads),
            na(mapped_reads),
            na(pct_mapped_reads),
            na(mapped_reads_dedup),
            na(pct_duplicates),
            na(unique_reads_mapq4),
            na(pct_reads_used),
            na(macs3_peaks_q10),
            na(macs3_peaks_q05),
            na(macs3_peaks_q01),
            na(frip_idr),
            na(frip_consensus_q001),
            na(frip_consensus_q005),
        ]
        print("\\t".join(out))
PY

  mv "\$dest/08_Summary/qc_master_table.sample.tsv.tmp" "\$dest/08_Summary/qc_master_table.sample.tsv"

  python3 - <<'PY' > "\$dest/08_Summary/peak_universe_matrix.${params.exploratory_universe_profile}.tsv.tmp"
import csv
import os
import subprocess
import shutil
from pathlib import Path
from collections import OrderedDict

samples_master = Path("${params.samples_master}")
chipfilter_out = Path("${params.chipfilter_out}")
chipseeker_out = Path("${params.chipseeker_out}")
peak_consensus_out = Path("${params.peak_consensus_out}")
universe_profile = "${params.exploratory_universe_profile}"
presence_threshold = float("${params.exploratory_presence_cpm_threshold}")

universe_bed = peak_consensus_out / universe_profile / "universe_peaks.bed"
if not universe_bed.exists():
    raise SystemExit(f"Universe BED not found: {universe_bed}")

universe_label = "universe_" + universe_profile.replace("consensus_", "")

def resolve_exe(name):
    candidates = [
        shutil.which(name),
        f"/usr/local/bin/{name}",
        f"/usr/bin/{name}",
        f"/bin/{name}",
    ]
    for c in candidates:
        if c and Path(c).exists():
            return c
    raise SystemExit(f"Executable not found in task environment: {name}")

bedtools_bin = resolve_exe("bedtools")

sample_rows = []
with samples_master.open(newline="") as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        enabled = (row.get("enabled") or "").strip().lower()
        if enabled not in ("", "true"):
            continue
        if (row.get("is_control") or "").strip().lower() == "true":
            continue
        sample_id = (row.get("sample_id") or "").strip()
        condition = (row.get("condition") or "").strip()
        replicate = (row.get("replicate") or "").strip()
        clean_bam = chipfilter_out / f"{sample_id}.clean.bam"
        stat_tsv = chipfilter_out / f"{sample_id}.chipfilter.stats.tsv"
        if not clean_bam.exists():
            continue
        usable_reads = None
        if stat_tsv.exists():
            rows = stat_tsv.read_text().strip().splitlines()
            if len(rows) >= 2:
                vals = rows[1].split("\\t")
                if len(vals) > 3 and vals[3]:
                    try:
                        usable_reads = float(vals[3])
                    except Exception:
                        usable_reads = None
        sample_rows.append({
            "sample_id": sample_id,
            "condition": condition,
            "replicate": replicate,
            "bam": clean_bam,
            "usable_reads": usable_reads,
        })

if not sample_rows:
    raise SystemExit("No enabled non-control clean BAM files found for peak universe matrix")

multicov_out = subprocess.check_output(
    [bedtools_bin, "multicov", "-bams", *[str(x["bam"]) for x in sample_rows], "-bed", str(universe_bed)],
    text=True
)

def load_annotation_rows():
    ann = {}

    direct = chipseeker_out / f"{universe_label}__universe_peaks" / f"annotated_peaks.{universe_label}__universe_peaks.tsv"
    if direct.exists():
        with direct.open(newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\\t")
            for row in reader:
                key = (
                    str(row.get("seqnames", "")).strip(),
                    str(row.get("start", "")).strip(),
                    str(row.get("end", "")).strip(),
                )
                ann[key] = {
                    "annotation": (row.get("annotation") or "").strip(),
                    "gene_id": (row.get("geneId") or row.get("gene_id") or "").strip(),
                    "gene_name": (row.get("SYMBOL") or row.get("gene_name") or "").strip(),
                    "distance_to_tss": (row.get("distanceToTSS") or "").strip(),
                    "annotation_source": universe_label
                }
        return ann

    fallback_rows = []
    for d in sorted(chipseeker_out.glob("consensus_q0.05__*")):
        f = d / f"annotated_peaks.{d.name}.tsv"
        if not f.exists():
            continue
        with f.open(newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\\t")
            for row in reader:
                seq = str(row.get("seqnames", "")).strip()
                start = str(row.get("start", "")).strip()
                end = str(row.get("end", "")).strip()
                if not seq or not start or not end:
                    continue
                fallback_rows.append({
                    "seq": seq,
                    "start": start,
                    "end": end,
                    "annotation": (row.get("annotation") or "").strip(),
                    "gene_id": (row.get("geneId") or row.get("gene_id") or "").strip(),
                    "gene_name": (row.get("SYMBOL") or row.get("gene_name") or "").strip(),
                    "distance_to_tss": (row.get("distanceToTSS") or "").strip(),
                })

    if not fallback_rows:
        return ann

    tmpdir = Path(".")
    universe4 = tmpdir / "universe.annot.input.bed"
    fallback4 = tmpdir / "fallback.annot.input.bed"
    with universe4.open("w") as fh:
        with universe_bed.open() as ub:
            for idx, line in enumerate(ub, start=1):
                parts = line.rstrip().split("\\t")
                if len(parts) < 3:
                    continue
                fh.write("\\t".join(parts[:3] + [f"PU_{idx}"]) + "\\n")
    with fallback4.open("w") as fh:
        for idx, row in enumerate(fallback_rows, start=1):
            meta = "|".join([
                row["annotation"].replace("\\t", " "),
                row["gene_id"].replace("\\t", " "),
                row["gene_name"].replace("\\t", " "),
                row["distance_to_tss"].replace("\\t", " "),
            ])
            fh.write("\\t".join([row["seq"], row["start"], row["end"], f"FB_{idx}", meta]) + "\\n")

    try:
        intersect = subprocess.check_output(
            [bedtools_bin, "intersect", "-a", str(universe4), "-b", str(fallback4), "-wa", "-wb"],
            text=True
        )
        for line in intersect.splitlines():
            parts = line.rstrip().split("\\t")
            if len(parts) < 9:
                continue
            key = (parts[0], parts[1], parts[2])
            meta = parts[8].split("|")
            if key not in ann:
                ann[key] = {
                    "annotation": meta[0] if len(meta) > 0 else "",
                    "gene_id": meta[1] if len(meta) > 1 else "",
                    "gene_name": meta[2] if len(meta) > 2 else "",
                    "distance_to_tss": meta[3] if len(meta) > 3 else "",
                    "annotation_source": "consensus_q0.05_overlap"
                }
    finally:
        for p in (universe4, fallback4):
            try:
                p.unlink()
            except Exception:
                pass
    return ann

ann_map = load_annotation_rows()

conditions = []
for row in sample_rows:
    if row["condition"] and row["condition"] not in conditions:
        conditions.append(row["condition"])

header = ["peak_id", "chr", "start", "end", "length"] + conditions
header += [f"raw_{row['sample_id']}" for row in sample_rows]
header += [f"cpm_{row['sample_id']}" for row in sample_rows]
header += ["annotation", "gene_id", "gene_name", "distance_to_tss", "annotation_source"]
print("\\t".join(header))

for idx, line in enumerate(multicov_out.splitlines(), start=1):
    parts = line.rstrip().split("\\t")
    if len(parts) < 3 + len(sample_rows):
        continue
    chrom, start, end = parts[:3]
    counts = []
    for x in parts[3:3 + len(sample_rows)]:
        try:
            counts.append(int(float(x)))
        except Exception:
            counts.append(0)
    cpms = []
    for count, sample in zip(counts, sample_rows):
        usable = sample["usable_reads"]
        if usable and usable > 0:
            cpms.append((count / usable) * 1_000_000.0)
        else:
            cpms.append(None)

    cond_presence = OrderedDict()
    for cond in conditions:
        vals = [cpm for cpm, sample in zip(cpms, sample_rows) if sample["condition"] == cond and cpm is not None]
        cond_presence[cond] = "1" if any(v >= presence_threshold for v in vals) else "0"

    ann = ann_map.get((chrom, start, end), {})
    row = [
        f"PU_{idx}",
        chrom,
        start,
        end,
        str(int(end) - int(start))
    ]
    row += [cond_presence[c] for c in conditions]
    row += [str(x) for x in counts]
    row += [f"{x:.4f}" if x is not None else "NA" for x in cpms]
    row += [
        ann.get("annotation", "NA") or "NA",
        ann.get("gene_id", "NA") or "NA",
        ann.get("gene_name", "NA") or "NA",
        ann.get("distance_to_tss", "NA") or "NA",
        ann.get("annotation_source", "NA") or "NA",
    ]
    print("\\t".join(row))
PY

  mv "\$dest/08_Summary/peak_universe_matrix.${params.exploratory_universe_profile}.tsv.tmp" "\$dest/08_Summary/peak_universe_matrix.${params.exploratory_universe_profile}.tsv"

  cat > "\$dest/08_Summary/README_result_notes.md" << MD
# Final Delivery Notes

- Delivery level: ${delivery_level}
- `lean`: excludes large browser tracks (`.bw`) and deepTools matrix tables.
- `full`: includes browser tracks and deepTools matrix tables.
- If batch and condition are confounded, interpret differential results as exploratory.
- `peak_universe_matrix.${params.exploratory_universe_profile}.tsv` uses `${params.exploratory_universe_profile}/universe_peaks.bed` as a broad exploratory universe.
- Sample-level counts in the peak universe matrix are raw counts from `bedtools multicov` on `chipfilter_output/*.clean.bam`.
- Condition-level 0/1 columns are derived from CPM normalized by `unique_reads_mapq4` with threshold ${params.exploratory_presence_cpm_threshold}.
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
