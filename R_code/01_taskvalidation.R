# Task Validation

require(tidyverse)
require(arrow)
require(cowplot)
require(duckdb)
source("00_power_grid_fx.R")
con <- dbConnect(duckdb::duckdb(dbdir = "G:/duckdb/rr.db"))
dbExecute(con, "PRAGMA memory_limit = '10G'")

open_dataset("anccr_p1_3_extract.parquet") |> 
  to_duckdb(con = con, table_name = "anccr_sim") -> anccr_sim

open_dataset("td_p1_3_extract.parquet") |>
  to_duckdb(con = con, table_name = "td_sim") -> td_sim

td_sim |> select(alpha,gamma) |> distinct() |> collect() |> mutate(p = row_number()) -> td_params

# Task Validation 1
# Positive Trial on response

anccr_sim |>
  filter(events == 7) |>
  group_by(p,rep) |> 
  reframe(mDA = mean(DA), sdDA = sd(DA)) |>
  mutate(tval = mDA / sdDA) |>
  select(-mDA, -sdDA) |>
  pivot_wider(names_from = ephase, values_from = tval, names_prefix = "p") |>
  filter(p1 > 1.67, p2 > 1.67, p3 > 1.67) |>
  group_by(p) |>
  summarise(n = n()) |>
  filter(n > 94) |>
  pull(p) -> anccr_trialon_response

td_sim |>
  filter(events == 7) |>
  group_by(alpha,gamma,rep) |>
  mutate(tval = mean_DA / sd_DA) |>
  select(-mean_DA, -sd_DA) |>
  pivot_wider(names_from = ephase, values_from = tval, names_prefix = "p") |>
  filter(p1 > 1.67, p2 > 1.67, p3 > 1.67) |>
  group_by(alpha,gamma) |>
  summarise(n = n()) |>
  filter(n > 94) |> collect() |> left_join(td_params) |> pull(p) -> td_trialon_response

# Task Validation 2 and 3

#Read in effect size data

hyp1b_1c_anccr |> filter(Parameter == 'factor(events)') |> filter(Eta2_partial>0.06) |> group_by(p) |> reframe(n = n()) |> filter(n > 94) |> pull(p) -> anccr_hyp1b_response
hyp1b_1c_td |> filter(Parameter == 'factor(events)') |> filter(Eta2_partial>0.06) |> group_by(alpha,gamma) |> reframe(n = n()) |> filter(n > 94) |> collect() -> td_hyp1b_response

hyp1b_1c_anccr |> filter(Parameter == 'factor(ephase)') |> filter(Eta2_partial>0.06) |> group_by(p) |> reframe(n = n()) |> filter(n > 94) |> pull(p) -> anccr_hyp1b_response
hyp1b_1c_td |> filter(Parameter == 'factor(ephase)') |> filter(Eta2_partial>0.06) |> group_by(alpha,gamma) |> reframe(n = n()) |> filter(n > 94) |> collect() -> td_hyp1b_response


# Intersection of the three

intersect(anccr_trialon_response, anccr_hyp1b_response, anccr_hyp1c_response) -> anccr_response
intersect(td_trialon_response, td_hyp1b_response, td_hyp1c_response) -> td_response

#



  