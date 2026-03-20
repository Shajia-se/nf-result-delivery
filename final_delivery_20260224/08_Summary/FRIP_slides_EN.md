# FRiP Interpretation for ChIP-seq

## Slide 1. What is FRiP?

**FRiP** stands for **Fraction of Reads in Peaks**.

Formula:

`FRiP = reads overlapping peak regions / total mapped reads`

What it measures:
- How much of the sequencing signal is concentrated in called peak regions
- A compact indicator of ChIP enrichment and signal-to-noise ratio

How to interpret:
- Higher FRiP usually suggests stronger enrichment and cleaner signal
- Lower FRiP suggests weaker enrichment, higher background, or a very strict peak set
- FRiP should always be interpreted together with peak count, IDR, mapping statistics, and genome browser tracks

Speaker note:
FRiP is a standard ChIP-seq QC metric. It does not directly measure biology, but it helps us judge whether the signal is sufficiently concentrated in the peak regions to support downstream interpretation.

---

## Slide 2. What is in the FRiP result file?

Each file contains one summary row per sample with the following columns:

- `sample`: sample identifier
- `bam`: cleaned BAM file used for counting mapped reads
- `peaks`: peak file used to define enriched regions
- `in_peaks`: number of mapped reads overlapping the peak regions
- `total_mapped`: total number of mapped reads in the BAM file
- `FRiP`: `in_peaks / total_mapped`

Example:
- `in_peaks = 377,896`
- `total_mapped = 46,384,344`
- `FRiP = 0.008147`
- This means **0.81%** of mapped reads fall inside the final peak set

Speaker note:
In this pipeline, the peak file comes from IDR-filtered narrowPeak output, so the FRiP value reflects overlap with a relatively stringent and reproducible peak set.

---

## Slide 3. What data are used to calculate FRiP?

FRiP is calculated from **two inputs**:

1. **Mapped reads in the cleaned BAM file**
2. **Final peak regions in the IDR-filtered `narrowPeak` file**

Pipeline logic in this project:

1. Reads are cleaned and aligned to the reference genome
2. The aligned reads are stored in `*.clean.bam`
3. MACS3 calls enriched regions for each replicate: `*_peaks.narrowPeak`
4. IDR compares replicate peak sets and keeps the reproducible peaks
5. FRiP counts how many mapped reads fall inside those final IDR peak regions

Important clarification:
- `in_peaks` does **not** mean reads mapped to promoters only
- It means reads mapped to **any final called peak region**
- Those peaks may fall in promoters, enhancers, introns, exons, or intergenic regions

Speaker note:
This is the key point for interpretation. FRiP does not count reads in predefined gene annotations. It counts reads in experimentally defined peak regions derived from MACS3 and filtered by IDR.

---

## Slide 4. What do `in_peaks` and `total_mapped` mean?

`in_peaks`
- Reads that successfully mapped to the genome and also overlap the final peak intervals
- These are the reads contributing to the numerator of FRiP

`total_mapped`
- All reads that successfully mapped to the reference genome
- This includes both reads inside peaks and reads outside peaks

What is **not** included in `total_mapped`:
- Reads that failed alignment
- Low-quality or contaminated reads removed during preprocessing
- Reads that could not be assigned confidently to genomic positions

Conceptually:

`total_mapped = reads in peaks + reads mapped outside peaks`

`FRiP = reads in peaks / all mapped reads`

---

## Slide 5. What is the IDR peak set?

The peak regions used for FRiP are not arbitrary genomic regions and are not limited to promoters.

They are defined in two steps:

1. **MACS3 peak calling**
- For each replicate, MACS3 scans the genome and identifies regions with significant ChIP enrichment over background
- Output: `*_peaks.narrowPeak`

2. **IDR filtering**
- IDR compares replicate peak lists within the same condition
- It keeps peaks that are reproducible and consistently ranked between replicates
- Output used by FRiP: `*_idr.sorted.chr.narrowPeak`

Interpretation:
- MACS3 asks: “Where is the enrichment signal?”
- IDR asks: “Which of those peaks are reproducible?”

This makes the FRiP calculation more stringent and more biologically reliable.

---

## Slide 6. Why does FRiP matter?

FRiP is useful because it helps answer three questions:

1. Is the ChIP signal concentrated in enriched regions?
2. Are some samples clearly weaker than others?
3. Is the dataset strong enough for confident downstream interpretation?

Important caveats:
- FRiP depends on both read distribution and how peaks were defined
- A stringent peak set can lower FRiP
- Narrow transcription factor peaks often show lower FRiP than broad histone-mark peaks
- FRiP alone should not be used as a strict pass/fail rule

---

## Slide 7. FRiP results for the four samples

| Sample | in_peaks | total_mapped | FRiP | FRiP (%) |
|---|---:|---:|---:|---:|
| GAR1585 | 377,896 | 46,384,344 | 0.008147 | 0.81 |
| GAR1586 | 566,281 | 57,238,125 | 0.009893 | 0.99 |
| GAR0979 | 509,700 | 39,732,720 | 0.012828 | 1.28 |
| GAR0968 | 500,816 | 41,407,044 | 0.012095 | 1.21 |

Ranking from highest to lowest FRiP:

1. GAR0979
2. GAR0968
3. GAR1586
4. GAR1585

Key observation:
- The two `WT`-peak samples show higher FRiP than the two `TG`-peak samples in this set

---

## Slide 8. How to read these results

### GAR1585
- Lowest FRiP in the set: **0.81%**
- Reads are less concentrated in the peak regions
- Suggests weaker enrichment or higher background relative to the others

### GAR1586
- Slightly better than GAR1585: **0.99%**
- Signal is present, but still relatively modest

### GAR0979
- Highest FRiP in the set: **1.28%**
- Best signal concentration among the four samples

### GAR0968
- Very close to GAR0979: **1.21%**
- Also stronger than the two TG-related samples

Speaker note:
The differences are not dramatic, but there is a consistent pattern: GAR0979 and GAR0968 appear stronger by FRiP than GAR1585 and GAR1586.

---

## Slide 9. How should the results be analyzed?

Recommended interpretation workflow:

1. Confirm what was used to calculate FRiP
- BAM = cleaned mapped reads
- Peaks = final IDR-filtered reproducible peak set

2. Compare FRiP values across samples in the same experiment
- Higher FRiP usually means stronger signal concentration
- Look for weak outliers

3. Check whether low FRiP could be explained by strict peak filtering
- IDR-based peaks are more stringent than raw peak calls
- A low FRiP may reflect weak signal, strict filtering, or both

4. Integrate FRiP with other QC metrics
- peak count
- IDR reproducibility
- mapping rate
- duplication rate
- genome browser inspection

Main rule:
- Use FRiP as a **relative QC metric**, not as the only pass/fail standard

---

## Slide 10. Interpretation summary

What these data suggest:
- All four samples show some enrichment signal
- GAR0979 and GAR0968 are the stronger samples in this comparison
- GAR1585 is the weakest sample by FRiP
- Overall FRiP values are relatively low, so the dataset does not look like a very strong, high-enrichment ChIP-seq experiment based on FRiP alone

What this does **not** mean:
- It does not automatically mean the experiment failed
- It does not prove the biology is absent
- It does not replace replicate concordance and peak reproducibility checks

---

## Slide 11. Final conclusion

**Conclusion**

- FRiP indicates the fraction of mapped reads that fall inside the final peak regions
- In this dataset, FRiP ranges from **0.81% to 1.28%**
- `WT`-associated samples (GAR0979, GAR0968) perform better than `TG`-associated samples (GAR1586, GAR1585)
- The dataset appears **usable but not strongly enriched** based on FRiP alone
- Final interpretation should be confirmed with:
  - IDR reproducibility
  - peak counts
  - mapping and duplication metrics
  - visual inspection in a genome browser

Short presentation close:

“FRiP shows that signal enrichment is present in all four samples, but overall enrichment is modest. GAR0979 and GAR0968 perform best, while GAR1585 is the weakest. These data are interpretable, but the final conclusion should be supported by additional QC metrics rather than FRiP alone.”
