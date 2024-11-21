require(tidyverse)
require(arrow)

results_folder <- ""
experiment_file <- ""
experiment <- open_dataset(experiment_file) |>
  select(-reward, -IRI, -omission_id, -times) |>
  mutate(events = as.integer(events), ephase = as.integer(ephase), rep = as.integer(rep), t_id = as.integer(t_id)) |>
  collect()
result_files <- list.files(results_folder, pattern = "*.parquet", full.names = TRUE)

sum_results_folder <- file.path(results_folder, "summary")
dir.create(sum_results_folder, recursive = TRUE, showWarnings = FALSE)

#phase 1-3 summary
sum_save_function <- function(result_file, sum_results_folder) {
  out_file <- file.path(sum_results_folder, basename(result_file))
  if (!file.exists(out_file)) {
    require(arrow)
    require(tidyverse)
    # try to read the file, if it fails, return a message containing the file name
    tryCatch(
      {
        open_dataset(result_file) |>
          mutate(t_id = as.integer(t_id), p = as.integer(p)) |>
          collect() |>
          left_join(experiment) |>
          group_by(p, rep, ephase, events) |>
          slice_max(n = 50, order_by = t_id) |>
          write_parquet(sink = out_file)
      },
      error = function(e) {
        message(paste0("Error in file: ", result_file))
      }
    )
  }
}

#phase 4 summary
sum_save_function <- function(result_file, sum_results_folder) {
  out_file <- file.path(sum_results_folder, basename(result_file))
  if (!file.exists(out_file)) {
    require(arrow)
    require(tidyverse)
    # try to read the file, if it fails, return a message containing the file name
    tryCatch(
      {
        open_dataset(result_file) |>
          mutate(t_id = as.integer(t_id), p = as.integer(p)) |>
          collect() |>
          left_join(experiment) |>
          filter(ephase == 4) |>
          group_by(p, rep) |>
          mutate(e_lag = lag(events, n = 2, order_by = t_id)) |>
          filter(events %in% c(2, 3, 4, 5)) |>
          mutate(to = if_else(e_lag == 7, 1, 0)) |>
          group_by(p, rep, events, to) |>
          slice_max(n = 50, order_by = t_id) |>
          reframe(mean_DA = mean(DA), sdDA = sd(DA)) |>
          write_parquet(sink = out_file)
      },
      error = function(e) {
        message(paste0("Error in file: ", result_file))
      }
    )
  }
}
