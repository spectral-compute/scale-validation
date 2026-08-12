#!/usr/bin/env Rscript
#
# plot-scale-version-diff.R
#
# Compares SCALE's own measured runtime across two regression-fleet runs
# (i.e. two different SCALE versions, or the same version at two
# different points in time), independent of any comparison against
# native toolchains. This is a separate question from
# scale_vs_native_ratio_<metric>.csv (which run-regression-fleet.sh
# already produces via plot_heatmap.R for every run, and which remains
# the default/primary comparison): "is SCALE correct/fast relative to
# nvcc/hipcc" vs "did this SCALE release change anything relative to the
# last one" are different questions and are kept as separate outputs
# rather than combined into one heatmap.
#
# Reuses each run's own scale_vs_native_ratio_<metric>.csv rather than
# re-parsing raw LSB files -- that CSV already has the median SCALE
# runtime per (benchmark, size, device, architecture), which is exactly
# what's needed here. No dependency on lsb_common.R or the raw results/
# directory at all.
#
# Usage:
#   Rscript plot-scale-version-diff.R <run_dir_a> <run_dir_b> [out_dir] [--metric=kernel|total|both] [--label-a=X] [--label-b=Y]
#
# <run_dir_a> / <run_dir_b>: two regression-runs/<timestamp>-scale<version>
#   directories, as produced by run-regression-fleet.sh. Order matters
#   only for which side is "before" and which is "after" in the ratio
#   (B / A) -- pass the older/baseline run as run_dir_a.
#
# [out_dir]: where to write outputs. Default: a new
#   regression-runs/version-diff-<labelA>-vs-<labelB>/ directory,
#   sibling to both run directories.
#
# --metric: which metric's ratio CSV to diff (kernel, total, or both).
#   Default: both, matching plot_heatmap.R's own default.
#
# --label-a / --label-b: override the version labels used in output
#   filenames and plot titles. Default: auto-detected from each run
#   directory's own "-scale<version>" suffix.
#
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(stringr)
  library(tidyr)
  library(scales)
})

log_msg <- function(fmt, ...) {
  message(sprintf(paste0("[%s] ", fmt), format(Sys.time(), "%H:%M:%S"), ...))
}

args <- commandArgs(trailingOnly = TRUE)

metric_flag <- str_match(args, "^--metric=(.+)$")[, 2]
metric_flag <- metric_flag[!is.na(metric_flag)]
requested_metric <- if (length(metric_flag) > 0) metric_flag[1] else "both"

VALID_METRICS <- c("kernel", "total", "both")
if (!(requested_metric %in% VALID_METRICS)) {
  stop("Unknown --metric value: ", requested_metric, " (expected one of: ", paste(VALID_METRICS, collapse = ", "), ")")
}
metrics_to_run <- if (requested_metric == "both") c("kernel", "total") else requested_metric

label_a_flag <- str_match(args, "^--label-a=(.+)$")[, 2]
label_a_flag <- label_a_flag[!is.na(label_a_flag)]
label_b_flag <- str_match(args, "^--label-b=(.+)$")[, 2]
label_b_flag <- label_b_flag[!is.na(label_b_flag)]

positional <- args[!str_detect(args, "^--(metric|label-a|label-b)=")]

if (length(positional) < 2) {
  stop("Usage: Rscript plot-scale-version-diff.R <run_dir_a> <run_dir_b> [out_dir] [--metric=kernel|total|both] [--label-a=X] [--label-b=Y]")
}

run_dir_a <- positional[[1]]
run_dir_b <- positional[[2]]

if (!dir.exists(run_dir_a)) stop("run_dir_a does not exist: ", run_dir_a)
if (!dir.exists(run_dir_b)) stop("run_dir_b does not exist: ", run_dir_b)

infer_label <- function(run_dir) {
  m <- str_match(basename(run_dir), "-scale(.+)$")
  if (!is.na(m[1, 2])) m[1, 2] else basename(run_dir)
}

label_a <- if (length(label_a_flag) > 0) label_a_flag[1] else infer_label(run_dir_a)
label_b <- if (length(label_b_flag) > 0) label_b_flag[1] else infer_label(run_dir_b)

if (label_a == label_b) {
  log_msg("WARNING: both runs resolved to the same version label ('%s') -- pass --label-a/--label-b explicitly if these are genuinely different versions.", label_a)
}

out_dir <- if (length(positional) >= 3) {
  positional[[3]]
} else {
  file.path(dirname(run_dir_a), paste0("version-diff-", label_a, "-vs-", label_b))
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

log_msg("Comparing SCALE %s (a) vs SCALE %s (b)", label_a, label_b)
log_msg("  run_dir_a: %s", run_dir_a)
log_msg("  run_dir_b: %s", run_dir_b)
log_msg("  out_dir:   %s", out_dir)

architecture_labels <- list(nvidia = "NVIDIA", amd = "AMD")

for (metric in metrics_to_run) {
  csv_a <- file.path(run_dir_a, "plots", metric, paste0("scale_vs_native_ratio_", metric, ".csv"))
  csv_b <- file.path(run_dir_b, "plots", metric, paste0("scale_vs_native_ratio_", metric, ".csv"))

  if (!file.exists(csv_a)) {
    log_msg("SKIPPING metric=%s: %s not found (did that run's heatmap step complete?)", metric, csv_a)
    next
  }
  if (!file.exists(csv_b)) {
    log_msg("SKIPPING metric=%s: %s not found (did that run's heatmap step complete?)", metric, csv_b)
    next
  }

  df_a <- read_csv(csv_a, show_col_types = FALSE) |>
    select(benchmark, size, device, architecture, scale_implementation, scale_runtime_s) |>
    rename(scale_runtime_s_a = scale_runtime_s, scale_implementation_a = scale_implementation)

  df_b <- read_csv(csv_b, show_col_types = FALSE) |>
    select(benchmark, size, device, architecture, scale_implementation, scale_runtime_s) |>
    rename(scale_runtime_s_b = scale_runtime_s, scale_implementation_b = scale_implementation)

  joined <- full_join(df_a, df_b, by = c("benchmark", "size", "device", "architecture"))

  mismatched_impl <- joined |>
    filter(!is.na(scale_implementation_a), !is.na(scale_implementation_b), scale_implementation_a != scale_implementation_b)

  if (nrow(mismatched_impl) > 0) {
    log_msg("WARNING metric=%s: %d row(s) have a different SCALE implementation name between the two runs (e.g. cuda/scale-nvidia vs cuda/scale-amd) for the same benchmark/size/device/architecture -- check for a device-labeling mixup before trusting this comparison:", metric, nrow(mismatched_impl))
    for (i in seq_len(min(nrow(mismatched_impl), 10))) {
      row <- mismatched_impl[i, ]
      log_msg("  %s / %s / %s / %s: a=%s b=%s", row$architecture, row$benchmark, row$size, row$device, row$scale_implementation_a, row$scale_implementation_b)
    }
  }

  missing <- joined |> filter(is.na(scale_runtime_s_a) | is.na(scale_runtime_s_b))
  if (nrow(missing) > 0) {
    log_msg(
      "%d (architecture, benchmark, size, device) combination(s) present in only one run -- skipped:",
      nrow(missing)
    )
    for (i in seq_len(min(nrow(missing), 20))) {
      row <- missing[i, ]
      log_msg(
        "  missing %s: %s / %s / %s / %s",
        ifelse(is.na(row$scale_runtime_s_a), paste0("from ", label_a), paste0("from ", label_b)),
        row$architecture, row$benchmark, row$size, row$device
      )
    }
    if (nrow(missing) > 20) log_msg("  ... and %d more", nrow(missing) - 20)
  }

  diff_df <- joined |>
    filter(!is.na(scale_runtime_s_a), !is.na(scale_runtime_s_b)) |>
    mutate(
      ratio = scale_runtime_s_b / scale_runtime_s_a,
      log2_ratio = log2(ratio)
    )

  if (nrow(diff_df) == 0) {
    log_msg("SKIPPING metric=%s: no (benchmark, size, device) combination present in both runs.", metric)
    next
  }

  metric_out_dir <- file.path(out_dir, metric)
  dir.create(metric_out_dir, recursive = TRUE, showWarnings = FALSE)

  csv_out <- file.path(metric_out_dir, paste0("scale_version_diff_", metric, ".csv"))
  write_csv(diff_df, csv_out)
  log_msg("wrote diff table: %s (%d rows)", csv_out, nrow(diff_df))

  max_abs_log2 <- max(abs(diff_df$log2_ratio), na.rm = TRUE)
  colour_limit <- max(max_abs_log2, 0.1)

  metric_label <- switch(metric,
    kernel = "kernel-region time",
    total = "total measured region time"
  )

  for (arch in names(architecture_labels)) {
    arch_df <- diff_df |> filter(architecture == arch)
    if (nrow(arch_df) == 0) {
      log_msg("skipping %s heatmap: no data for this architecture", arch)
      next
    }

    arch_label <- architecture_labels[[arch]]
    n_devices <- n_distinct(arch_df$device)
    n_benchmarks <- n_distinct(arch_df$benchmark)

    p <- ggplot(arch_df, aes(x = device, y = benchmark, fill = log2_ratio)) +
      geom_tile(colour = "white", linewidth = 0.4) +
      geom_text(aes(label = paste0(number(ratio, accuracy = 0.01), "x")), size = 3, colour = "black") +
      facet_wrap(~size, nrow = 1, labeller = labeller(size = str_to_title)) +
      scale_fill_gradient2(
        low = "#1F77B4",
        mid = "white",
        high = "#D62728",
        midpoint = 0,
        limits = c(-colour_limit, colour_limit),
        breaks = c(-colour_limit, 0, colour_limit),
        labels = c(paste0(label_b, " faster"), "no change", paste0(label_b, " slower")),
        name = NULL
      ) +
      theme_bw(base_size = 13) +
      theme(
        axis.text.x = element_text(angle = 40, hjust = 1),
        panel.grid = element_blank(),
        legend.position = "bottom",
        legend.key.width = unit(2.2, "cm")
      ) +
      labs(
        x = NULL,
        y = NULL,
        title = paste0("SCALE ", label_a, " vs ", label_b, " (", arch_label, "): ", metric_label),
        subtitle = paste0("Cell = median(SCALE ", label_b, " ", metric_label, ") / median(SCALE ", label_a, " ", metric_label, ")")
      )

    out_path <- file.path(metric_out_dir, paste0("scale_version_diff_heatmap_", arch, "_", metric, ".pdf"))
    ggsave(out_path, p, width = max(6, 2.4 * n_devices + 2), height = max(3, 0.55 * n_benchmarks + 2), limitsize = FALSE)
    log_msg("wrote %s heatmap: %s (%d benchmark(s), %d device(s))", arch_label, out_path, n_benchmarks, n_devices)
  }
}

message("Done. Wrote version-diff outputs under: ", out_dir)
