require(tidyverse)
require(arrow)

results_folder <- ""
exp_file <- ""
experiment <- read_parquet(exp_file)
results_files <- list.files(path = results_folder, pattern = "td_b6*", full.names = TRUE)

extract_td_fixed <- function(result_file) {
  require(tidyverse)
  require(arrow)
  sum_results_folder <- ""
  p4_results_folder <- ""
  out_file <- file.path(sum_results_folder, basename(result_file))
  out_p4_file <- file.path(p4_results_folder, basename(result_file))
  if (!file.exists(out_file)) {
    read_parquet(result_file) -> cur_file
    cur_file |>
      filter(t_id > 0) |>
      mutate(t_actual = t * 0.25) |>
      select(t_id, t, t_actual) -> cur_times
    cur_file |>
      pull(rep) |>
      unique() -> cur_rep
    experiment |> filter(rep == cur_rep) -> exp_rep
    exp_rep |>
      select(events, times, t_id) |>
      mutate(row_id = row_number()) -> exp_times
    
    cur_times |>
      pull(t_actual) |>
      diff() -> short_vec
    exp_times |>
      pull(times) |>
      diff() -> long_vec
    
    elements_to_remove <- length(long_vec) - length(short_vec)
    remove_list <- vector()
    for (i in seq(1, length(short_vec))) {
      while (abs(long_vec[i] - short_vec[i]) > 0.25) {
        long_vec <- long_vec[-i]
        remove_list <- append(remove_list, i)
      }
    }
    
    exp_rep[-remove_list, ] |>
      select(-t_id) |>
      mutate(t = cur_times$t) |>
      mutate(t = if_else(events == 1, t + 1, t)) -> fixed_exp
    
    fixed_exp |>
      filter(ephase < 4) |>
      group_by(events,ephase) |>
      slice_max(n = 25, order_by = t) |>
      left_join(cur_file) -> p1_3
    fixed_exp |>
       filter(ephase == 4) |>
       mutate(to = if_else(lag(events) == 7, 1, 0)) |>
       na.omit() |>
       group_by(events, to) |>
       slice_max(n = 25, order_by = t) |>
       left_join(cur_file) -> p4
    p1_3 |> ungroup() |> write_parquet(out_file)
    p4 |> ungroup() |> write_parquet(out_p4_file)
  }
  return(1)
}

require(parallel)

cl <- makeCluster(12)
on.exit(stopCluster(cl))
clusterExport(cl, "experiment")

v <- parLapply(cl,results_files,extract_td_fixed)