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
