#!/usr/bin/env Rscript
#
# plot-scale-version-diff.R
#
# Diffs SCALE's OWN measured runtime between two regression-fleet runs of
# different SCALE versions (baseline vs candidate) -- distinct from, and
# independent of, plot_heatmap.R's SCALE-vs-native comparison, which this
# script does not touch or reproduce. Written to answer "did anything
# regress between these two SCALE versions", for
# compare-scale-versions.sh / run-regression-ci.sh's version-diff and both
# modes -- both of which already call this script; it is not usually
# invoked directly, but can be (see Usage) against any two existing
# regression-runs/ directories without re-running the fleet.
#
# Usage:
#   Rscript plot-scale-version-diff.R <baseline_run_dir> <candidate_run_dir> [--metric=total|kernel|runtime|auto]
#
# <baseline_run_dir> / <candidate_run_dir> are two
# regression-runs/<timestamp>-scale<version>/ directories as produced by
# run-regression-fleet.sh (each must contain a results/ subdirectory). The
# SCALE version compared is parsed from each directory's own name (the
# "-scale<version>" suffix) -- not passed as a separate argument -- so
# both directories must follow that naming convention.
#
# Cell value: median(candidate metric) / median(baseline metric), per
# (benchmark, size, device, implementation).
#   ratio < 1  -> candidate faster than baseline (improvement)
#   ratio = 1  -> parity
#   ratio > 1  -> candidate slower than baseline (regression)
#
# Metric selection: same semantics as plot_heatmap.R (--metric=total|kernel|runtime|auto,
# default runs both kernel and total in one invocation). See that script's
# own header for the detailed caveats on each metric choice, particularly
# why "runtime" can understate real differences for stabilize-to-~2s
# benchmarks -- unchanged here.
#
# Only SCALE's own implementations (cuda/scale-nvidia, cuda/scale-amd) are
# compared -- native toolchains (cuda/nvcc, hip/hipcc) are deliberately
# excluded, since whether nvcc/hipcc itself changed between two SCALE
# release checkouts isn't a SCALE regression question. If the underlying
# system (driver, native compiler) changed between the two runs, that's a
# separate question this script doesn't answer -- plot_heatmap.R's own
# per-run native numbers are the place to look for that, one run at a
# time.
#
# Output: nested under out_dir/<metric>/, one heatmap/CSV pair per
# architecture present in the data:
#   scale_version_diff_heatmap_nvidia.pdf / scale_version_diff_ratio_nvidia.csv
#   scale_version_diff_heatmap_amd.pdf    / scale_version_diff_ratio_amd.csv
#
# out_dir is auto-derived as a sibling of both input directories:
#   <parent-of-both>/version-diff-<baseline_version>-vs-<candidate_version>-<UTC timestamp>/
# matching what run-regression-ci.sh's collation step
# (copy_version_diff_heatmap()) already globs for by that exact naming
# pattern -- if you change this naming, update that function too.
#
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(stringr)
  library(tidyr)
  library(readr)
  library(scales)
})
# Resolve this script's own directory the same way plot_heatmap.R and
# plot_lsb.R do -- but unlike those two, this script does NOT live next
# to lsb_common.R. compare-scale-versions.sh invokes this from
# scale-validation/ExtendedOpenDwarfs/regression/ (see that script's own
# header for why it lives there), whereas lsb_common.R lives in the
# SEPARATE standalone EOD checkout's scripts/ directory (a sibling of
# scale-validation itself) -- the same place plot_heatmap.R and
# plot_lsb.R live. Mirror compare-scale-versions.sh's own EOD_REPO_ROOT
# computation (three dirnames up from regression/, then into
# ExtendedOpenDwarfs/scripts/) rather than assuming "next to me", which
# would look in regression/ and fail to find it.
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
VALID_METRICS <- c("auto", "runtime", "total", "kernel")
DEFAULT_METRICS <- c("kernel", "total")
metric_flag <- str_match(args, "^--metric=(.+)$")[, 2]
metric_flag <- metric_flag[!is.na(metric_flag)]
if (length(metric_flag) > 0) {
  requested_metrics <- str_split(metric_flag[1], ",")[[1]]
} else {
  requested_metrics <- DEFAULT_METRICS
}
bad_metrics <- setdiff(requested_metrics, VALID_METRICS)
if (length(bad_metrics) > 0) {
  stop(
    "Unknown --metric value(s): ", paste(bad_metrics, collapse = ", "),
    " (expected one or more of: ", paste(VALID_METRICS, collapse = ", "), ")"
  )
}
positional <- args[!str_detect(args, "^--metric=")]
if (length(positional) < 2) {
  stop("Usage: Rscript plot-scale-version-diff.R <baseline_run_dir> <candidate_run_dir> [--metric=total|kernel|runtime|auto]")
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
log_msg(
  "comparing SCALE %s (baseline: %s) vs SCALE %s (candidate: %s)",
  baseline_version, baseline_run_dir, candidate_version, candidate_run_dir
)

if (!identical(dirname(baseline_run_dir), dirname(candidate_run_dir))) {
  log_msg(
    "WARNING: baseline and candidate run directories are not siblings (%s vs %s) -- output will be written next to the baseline run",
    dirname(baseline_run_dir), dirname(candidate_run_dir)
  )
}
runs_root <- dirname(baseline_run_dir)
timestamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
out_root <- file.path(runs_root, sprintf("version-diff-%s-vs-%s-%s", baseline_version, candidate_version, timestamp))
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
log_msg("writing output to %s", out_root)

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

# Only SCALE's own implementations -- see file header for why native
# toolchains are excluded here.
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

run_for_metric <- function(metric, df, out_root) {
  if (metric == "auto") {
    runtime_coverage_df <- df |>
      distinct(role, benchmark, size, device, implementation, run, runtime_s)
    frac_with_runtime <- mean(!is.na(runtime_coverage_df$runtime_s))
    if (frac_with_runtime >= 0.5) {
      metric <- "runtime"
    } else {
      metric <- "total"
      log_msg(
        "auto metric: only %.0f%% of configs have a '# Runtime:' header -- falling back to metric=total. Pass --metric=runtime or --metric=kernel to override.",
        100 * frac_with_runtime
      )
    }
  }
  out_dir <- file.path(out_root, metric)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  log_msg("--- metric=%s: writing outputs to %s ---", metric, out_dir)
  if (metric == "runtime") {
    runtime_df <- df |>
      distinct(role, benchmark, size, device, implementation, architecture, run, runtime_s) |>
      filter(!is.na(runtime_s))
  } else {
    region_filter <- df
    if (metric == "kernel") {
      region_filter <- df |> filter(region_class == "Kernel")
    }
    # Same per-region, per-repeat normalisation as plot_heatmap.R: divide
    # each region's summed time by its own repeat count BEFORE summing
    # across regions, so a stabilize-to-~2s region doesn't get compared
    # against a non-repeating region on unequal footing.
    runtime_df <- region_filter |>
      mutate(time_us_per_repeat = total_time_us / n_repeats) |>
      group_by(role, benchmark, size, device, implementation, architecture, run) |>
      summarise(runtime_s = sum(time_us_per_repeat) / 1e6, .groups = "drop")
  }
  if (nrow(runtime_df) == 0) {
    log_msg("SKIPPING metric=%s: no data found for cuda/scale-nvidia or cuda/scale-amd.", metric)
    return(invisible(NULL))
  }
  median_runtime <- runtime_df |>
    group_by(role, benchmark, size, device, implementation, architecture) |>
    summarise(runtime_s = median(runtime_s), n_runs = n(), .groups = "drop")
  wide_df <- median_runtime |>
    select(role, benchmark, size, device, implementation, architecture, runtime_s, n_runs) |>
    pivot_wider(
      names_from = role,
      values_from = c(runtime_s, n_runs),
      names_glue = "{role}_{.value}"
    )
  missing_pairs <- wide_df |>
    filter(is.na(baseline_runtime_s) | is.na(candidate_runtime_s))
  if (nrow(missing_pairs) > 0) {
    log_msg(
      "%d (architecture, benchmark, size, device) combination(s) only ran on one side -- skipped:",
      nrow(missing_pairs)
    )
    for (i in seq_len(min(nrow(missing_pairs), 20))) {
      row <- missing_pairs[i, ]
      log_msg(
        "  missing %s: %s / %s / %s / %s",
        ifelse(is.na(row$baseline_runtime_s), "baseline", "candidate"),
        row$architecture, row$benchmark, row$size, row$device
      )
    }
    if (nrow(missing_pairs) > 20) {
      log_msg("  ... and %d more", nrow(missing_pairs) - 20)
    }
  }
  paired_df <- wide_df |>
    filter(!is.na(baseline_runtime_s), !is.na(candidate_runtime_s)) |>
    mutate(ratio = candidate_runtime_s / baseline_runtime_s, log2_ratio = log2(ratio))
  if (nrow(paired_df) == 0) {
    log_msg("SKIPPING metric=%s: no complete baseline/candidate pairs.", metric)
    return(invisible(NULL))
  }
  for (arch in sort(unique(paired_df$architecture))) {
    arch_df <- paired_df |> filter(architecture == arch)
    csv_path <- file.path(out_dir, sprintf("scale_version_diff_ratio_%s.csv", arch))
    write_csv(arch_df, csv_path)
    log_msg("wrote %s (%d rows)", csv_path, nrow(arch_df))
    n_devices <- n_distinct(arch_df$device)
    n_rows_facet <- n_distinct(paste(arch_df$benchmark, arch_df$size))
    plot_width <- max(6, 1.1 * n_devices + 2.5)
    plot_height <- max(5, 0.3 * n_rows_facet + 2)
    max_abs_log2 <- max(abs(arch_df$log2_ratio), na.rm = TRUE)
    heatmap_plot <- ggplot(
      arch_df,
      aes(x = device, y = interaction(size, benchmark, sep = " / "), fill = log2_ratio)
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
          "SCALE %s vs %s (%s) -- %s",
          candidate_version, baseline_version, toupper(arch), metric
        ),
        subtitle = "ratio > 1 (red) = candidate slower than baseline; < 1 (blue) = candidate faster"
      ) +
      theme_bw(base_size = 11) +
      theme(axis.text.x = element_text(angle = 30, hjust = 1))
    pdf_path <- file.path(out_dir, sprintf("scale_version_diff_heatmap_%s.pdf", arch))
    ggsave(pdf_path, heatmap_plot, width = plot_width, height = plot_height, limitsize = FALSE)
    log_msg("wrote %s", pdf_path)
  }
  invisible(NULL)
}

for (m in requested_metrics) {
  run_for_metric(m, df, out_root)
}
message("Wrote version-diff outputs to: ", out_root)
