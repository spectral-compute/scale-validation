#!/usr/bin/env Rscript
#
# plot-scale-version-diff-by-region.R
#
# Per-region companion to plot-scale-version-diff.R: same baseline vs
# candidate comparison, same SCALE-only filtering (cuda/scale-nvidia,
# cuda/scale-amd -- native toolchains excluded, see that script's own
# header for why), but broken down by individual LSB region (whatever a
# given benchmark actually measures -- e.g. a H2D copy, a kernel launch,
# a D2H copy) instead of collapsed to one number per (benchmark, size,
# device).
#
# The whole-benchmark ratio in plot-scale-version-diff.R can hide a real
# regression confined to one region that's offset by an improvement in
# another (or vice versa) -- this exists so a point-wise investigation
# can see exactly which region moved, not just whether the total did.
#
# Usage:
#   Rscript plot-scale-version-diff-by-region.R <baseline_run_dir> <candidate_run_dir> \
#       [--out-dir=<path>] [--baseline-label=<text>] [--candidate-label=<text>]
#
# <baseline_run_dir> / <candidate_run_dir>: same regression-runs/
# <timestamp>-scale<version>/ directories plot-scale-version-diff.R takes
# (each must contain a results/ subdirectory).
#
# --out-dir: write output directly here instead of auto-deriving a
# sibling "version-diff-<a>-vs-<b>-<timestamp>/" directory -- pass the
# SAME path given to plot-scale-version-diff.R's own --out-dir so both
# land under one comparison's output tree. compare-scale-versions.sh does
# this automatically.
#
# --baseline-label / --candidate-label: text shown in plot titles instead
# of the version string parsed from each directory's own name -- see
# plot-scale-version-diff.R's header for why this exists (an exact
# nightly build identifier vs. a generic "-rc" label, for example).
#
# Cell value: median(candidate metric) / median(baseline metric), per
# (benchmark, size, device, region). Same per-repeat normalisation as
# plot-scale-version-diff.R's own metric=kernel/total (divide each
# region's summed time by its own repeat count before comparing, so a
# stabilize-to-~2s region isn't compared against a non-repeating region
# on unequal footing) -- applied to every region here, not just
# Kernel-classified ones, and not collapsed to a single per-benchmark sum.
#
# Output: nested under <out-dir>/by-region/, one heatmap PDF per
# (architecture, benchmark) plus one combined CSV per architecture:
#   by-region/scale_version_diff_region_ratio_nvidia.csv
#   by-region/scale_version_diff_region_ratio_amd.csv
#   by-region/nvidia/<benchmark>_region_diff.pdf
#   by-region/amd/<benchmark>_region_diff.pdf
#
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(stringr)
  library(tidyr)
  library(readr)
  library(scales)
})
# Resolve this script's own directory, then find lsb_common.R the same way
# plot-scale-version-diff.R does -- see that script's own header for why
# the path computation looks three directories up rather than "next to
# me" (this script lives alongside it, in scale-validation/
# ExtendedOpenDwarfs/regression/, not next to lsb_common.R).
.script_dir <- tryCatch({
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1])))
  } else {
    getwd()
  }
}, error = function(e) getwd())
.lsb_common_path <- file.path(
  dirname(dirname(dirname(.script_dir))), "ExtendedOpenDwarfs", "scripts", "lsb_common.R"
)
if (!file.exists(.lsb_common_path)) {
  stop(
    "Could not find lsb_common.R at ", .lsb_common_path, " -- expected the standalone EOD checkout ",
    "(sibling of scale-validation, holding plot_heatmap.R/plot_lsb.R/lsb_common.R) to live there, ",
    "three directories above wherever this script (", .script_dir, ") itself lives. ",
    "If either checkout has moved, update this path computation to match."
  )
}
source(.lsb_common_path)

args <- commandArgs(trailingOnly = TRUE)
out_dir_flag <- str_match(args, "^--out-dir=(.+)$")[, 2]
out_dir_flag <- out_dir_flag[!is.na(out_dir_flag)]
baseline_label_flag <- str_match(args, "^--baseline-label=(.+)$")[, 2]
baseline_label_flag <- baseline_label_flag[!is.na(baseline_label_flag)]
candidate_label_flag <- str_match(args, "^--candidate-label=(.+)$")[, 2]
candidate_label_flag <- candidate_label_flag[!is.na(candidate_label_flag)]
positional <- args[!str_detect(args, "^--(out-dir|baseline-label|candidate-label)=")]
if (length(positional) < 2) {
  stop("Usage: Rscript plot-scale-version-diff-by-region.R <baseline_run_dir> <candidate_run_dir> [--out-dir=..] [--baseline-label=..] [--candidate-label=..]")
}
baseline_run_dir <- normalizePath(positional[[1]])
candidate_run_dir <- normalizePath(positional[[2]])

extract_scale_version <- function(run_dir) {
  m <- str_match(basename(run_dir), "-scale(.+)$")
  if (is.na(m[1, 2])) {
    stop(
      "Could not parse a SCALE version out of directory name '", basename(run_dir),
      "' -- expected it to end in '-scale<version>' (the naming run-regression-fleet.sh itself uses)."
    )
  }
  m[1, 2]
}
baseline_version <- extract_scale_version(baseline_run_dir)
candidate_version <- extract_scale_version(candidate_run_dir)
baseline_label <- if (length(baseline_label_flag) > 0) baseline_label_flag[1] else baseline_version
candidate_label <- if (length(candidate_label_flag) > 0) candidate_label_flag[1] else candidate_version
log_msg(
  "region-diff: comparing SCALE %s (baseline: %s) vs SCALE %s (candidate: %s)",
  baseline_label, baseline_run_dir, candidate_label, candidate_run_dir
)

if (length(out_dir_flag) > 0) {
  out_root <- out_dir_flag[1]
} else {
  runs_root <- dirname(baseline_run_dir)
  timestamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  out_root <- file.path(runs_root, sprintf("version-diff-%s-vs-%s-%s", baseline_version, candidate_version, timestamp))
}
by_region_dir <- file.path(out_root, "by-region")
dir.create(by_region_dir, recursive = TRUE, showWarnings = FALSE)
log_msg("writing region-diff output to %s", by_region_dir)

baseline_results_dir <- file.path(baseline_run_dir, "results")
candidate_results_dir <- file.path(candidate_run_dir, "results")
if (!dir.exists(baseline_results_dir)) {
  stop("No results/ directory under baseline run: ", baseline_run_dir)
}
if (!dir.exists(candidate_results_dir)) {
  stop("No results/ directory under candidate run: ", candidate_run_dir)
}

df_baseline <- read_lsb_cached(baseline_results_dir) |> mutate(role = "baseline")
df_candidate <- read_lsb_cached(candidate_results_dir) |> mutate(role = "candidate")
df <- bind_rows(df_baseline, df_candidate)
log_msg(
  "loaded %s rows total (baseline=%s, candidate=%s)",
  comma(nrow(df)), comma(nrow(df_baseline)), comma(nrow(df_candidate))
)

# Only SCALE's own implementations -- see plot-scale-version-diff.R's own
# header for why native toolchains are excluded here too.
SCALE_IMPLS <- c(
  "cuda/scale-nvidia" = "nvidia",
  "cuda/scale-amd" = "amd"
)
df <- df |>
  filter(implementation %in% names(SCALE_IMPLS)) |>
  mutate(architecture = unname(SCALE_IMPLS[implementation]))
if (nrow(df) == 0) {
  stop("No cuda/scale-nvidia or cuda/scale-amd rows found in either run -- nothing to diff.")
}

# Same per-region, per-repeat normalisation as plot-scale-version-diff.R's
# own metric=kernel/total -- divide each region's summed time by its own
# repeat count before comparing. Unlike that script, every region is kept
# here (not just Kernel-classified, and not collapsed to one per-benchmark
# sum) -- that's the whole point of this breakdown.
region_runtime_df <- df |>
  mutate(time_us_per_repeat = total_time_us / n_repeats) |>
  group_by(role, benchmark, size, device, implementation, architecture, region, run) |>
  summarise(runtime_s = sum(time_us_per_repeat) / 1e6, .groups = "drop")
if (nrow(region_runtime_df) == 0) {
  stop("No per-region data found for cuda/scale-nvidia or cuda/scale-amd.")
}
median_region_runtime <- region_runtime_df |>
  group_by(role, benchmark, size, device, implementation, architecture, region) |>
  summarise(runtime_s = median(runtime_s), n_runs = n(), .groups = "drop")
wide_df <- median_region_runtime |>
  select(role, benchmark, size, device, implementation, architecture, region, runtime_s, n_runs) |>
  pivot_wider(
    names_from = role,
    values_from = c(runtime_s, n_runs),
    names_glue = "{role}_{.value}"
  )
missing_pairs <- wide_df |>
  filter(is.na(baseline_runtime_s) | is.na(candidate_runtime_s))
if (nrow(missing_pairs) > 0) {
  log_msg(
    "%d (architecture, benchmark, size, device, region) combination(s) only ran on one side -- skipped",
    nrow(missing_pairs)
  )
}
paired_df <- wide_df |>
  filter(!is.na(baseline_runtime_s), !is.na(candidate_runtime_s)) |>
  mutate(ratio = candidate_runtime_s / baseline_runtime_s, log2_ratio = log2(ratio))
if (nrow(paired_df) == 0) {
  stop("No complete baseline/candidate region pairs -- nothing to plot.")
}

for (arch in sort(unique(paired_df$architecture))) {
  arch_dir <- file.path(by_region_dir, arch)
  dir.create(arch_dir, recursive = TRUE, showWarnings = FALSE)
  arch_df <- paired_df |> filter(architecture == arch)
  csv_path <- file.path(by_region_dir, sprintf("scale_version_diff_region_ratio_%s.csv", arch))
  write_csv(arch_df, csv_path)
  log_msg("wrote %s (%d rows)", csv_path, nrow(arch_df))
  for (bench in sort(unique(arch_df$benchmark))) {
    bench_df <- arch_df |> filter(benchmark == bench)
    n_devices <- n_distinct(bench_df$device)
    n_rows_facet <- n_distinct(paste(bench_df$size, bench_df$region))
    plot_width <- max(7, 1.1 * n_devices + 2.5)
    plot_height <- max(5, 0.3 * n_rows_facet + 2)
    max_abs_log2 <- max(abs(bench_df$log2_ratio), na.rm = TRUE)
    if (!is.finite(max_abs_log2) || max_abs_log2 == 0) {
      max_abs_log2 <- 1
    }
    subtitle_text <- str_wrap(
      "ratio > 1 (red) = candidate slower than baseline; < 1 (blue) = candidate faster",
      width = max(30, round(plot_width * 9))
    )
    heatmap_plot <- ggplot(
      bench_df,
      aes(x = device, y = interaction(region, size, sep = " / "), fill = log2_ratio)
    ) +
      geom_tile(colour = "white") +
      geom_text(aes(label = sprintf("%.2fx", ratio)), size = 2.6) +
      scale_fill_gradient2(
        low = "#1F77B4", mid = "white", high = "#D62728", midpoint = 0,
        limits = c(-max_abs_log2, max_abs_log2),
        name = "log2(candidate / baseline)"
      ) +
      labs(
        x = "Device",
        y = NULL,
        title = sprintf(
          "SCALE %s vs %s (%s / %s) -- per-region",
          candidate_label, baseline_label, toupper(arch), bench
        ),
        subtitle = subtitle_text
      ) +
      theme_bw(base_size = 11) +
      theme(axis.text.x = element_text(angle = 30, hjust = 1))
    pdf_path <- file.path(arch_dir, sprintf("%s_region_diff.pdf", bench))
    ggsave(pdf_path, heatmap_plot, width = plot_width, height = plot_height, limitsize = FALSE)
    log_msg("wrote %s", pdf_path)
  }
}
message("Wrote per-region version-diff outputs to: ", by_region_dir)
