power_grid <- function(summary_table,sd_input,lower_limit,upper_limit) {
  require(tidyverse)
  require(multidplyr)
  require(duckdb)
  
  con <- dbConnect(duckdb::duckdb(dbdir = "F:/duckdb/duck_power.db"))
  dbExecute(con, "PRAGMA memory_limit = '10G'")
  
  summary_table |>
    ungroup() |>
    mutate(param_num = row_number()) -> asim_sum
  egrid <- expand_grid(t1 = seq(lower_limit,upper_limit, 0.005))
  
  clust <- new_cluster(20)
  cluster_library(clust, "tidyverse")
  cluster_library(clust, "broom")
  cluster_library(clust, "pwr")
  
  expand_grid(asim_sum, egrid) |>
    mutate(d = abs((t1 - mean_a1) / sd_input)) |>
    rowwise() |>
    partition(clust) |>
    mutate(d = min(3, d) + 0.01) |>
    mutate(n = pwr.t.test(d = d, power = 0.95, type = "one.sample", alternative = "two.sided") |> tidy() |> pull(n)) |>
    collect() |>
    rename(n1 = n) |>
    select(param_num, t1, n1) -> vv1
  
  
  expand_grid(asim_sum, egrid) |>
    mutate(d = abs((t1 - mean_a2) / sd_input)) |>
    rowwise() |>
    partition(clust) |>
    mutate(d = min(3, d) + 0.01) |>
    mutate(n = pwr.t.test(d = d, power = 0.95, type = "one.sample", alternative = "two.sided") |> tidy() |> pull(n)) |>
    collect() |>
    rename(t2 = t1, n2 = n) |>
    select(param_num, t2, n2) -> vv2
  
  rm(clust)
  gc()
  
  
  
  vv1 |> to_duckdb(con) -> vv1db
  vv2 |> to_duckdb(con) -> vv2db
  
  inner_join(vv1db, vv2db, by = "param_num", relationship = "many-to-many") |>
    mutate(n = pmin(n1, n2)) |>
    group_by(t1, t2) |>
    summarise(max_mn = max(n)) -> rt
  
  rt <- rt |> collect()
  
  # close connection
  dbDisconnect(con, shutdown = TRUE)
  return(rt)
}
