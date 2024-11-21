# Calculate effect size of varying w

param_table |> pull(p) -> total_p_list # for ANCCR
td_param_table |> pull(p) -> total_p_list # for TD
# 100 reps of each, create table with cross join
expand_grid(rep = 1:100, p = total_p_list) |> mutate(idx = row_number()) -> all_combinations
all_combinations |> pull(idx) -> idx_list
# results folder

data_extract <- open_dataset("") # point to TD or ANCCR phase 1-3 extract

calc_eta_square <- function(idx) {
  require(tidyverse)
  require(lmer)
  require(effectsize)
  tryCatch(
    {
      all_combinations |>
        filter(idx == idx) |>
        pull(p) -> current_p
      all_combinations |>
        filter(idx == idx) |>
        pull(rep) -> current_rep

      data_extract |>
        filter(p == current_p, rep == current_rep, events %in% c(2, 3, 5)) |>
        group_by(ephase, events) |>
        mutate(repeat_id = row_number()) |>
        ungroup() -> temp_data

      lmer(DA ~ factor(ephase) * factor(events) + (1 | repeat_id), data = temp_data) |>
        effectsize::eta_squared() |>
        as_tibble() |>
        mutate(p = current_p, rep = current_rep) -> return_data
      return(return_data)
    },
    error = function(e) {
      message(paste0("Error in file: ", idx))
    }
  )
}

require(parallel)

cl <- makeCluster(8)
on.exit(stopCluster(cl))
clusterExport(cl, "data_extract")
clusterExport(cl, "all_combinations")

res <- parLapply(cl, idx_list, calc_eta_square)
