#Calculate effect size of varying w

param_table |> group_by(Tratio,k,w,theta,alpha_r) |> mutate(gp_id = cur_group_id()) -> param_table
param_table |> select(gp_id) |> distinct() |> pull(gp_id) -> gp_ids
data_extract <- open_dataset("") #anccr or td, if td label params combos with td_params
#results folder

calc_eta_square <- function(idx) {
  require(tidyverse)
  require(lmerTest)
  require(effectsize)
  tryCatch(
    {
      param_table |>
        filter(gp_id == idx) |>
        pull(p) -> p_list
      data_extract |>
        filter(p %in% p_list) |>
        left_join(param_table, by = join_by(p)) -> temp_data
      lmer(DA ~ factor(ephase) * w + (1 | rep), data = filter(temp_data,events==2,ephase<4)) |>
        eta_squared() |>
        as_tibble() |>
        mutate(gp_id = idx, events  = 2) -> return_data1
      lmer(DA ~ factor(ephase) * w + (1 | rep), data = filter(temp_data,events==3,ephase<4)) |>
        eta_squared() |>
        as_tibble() |>
        mutate(gp_id = idx, events  = 3) -> return_data2
      bind_rows(return_data1, return_data2) -> return_data
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
clusterExport(cl, "param_table")

res <- parLapply(cl, gp_ids, calc_eta_square)
bind_rows(res) -> hyp1b_1c_anccr #or hyp1b_1c_td

