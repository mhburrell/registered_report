# Figure 3 - Power Analysis

open_dataset("G:\\Model Data\\ANCCR RR\\rr_b6_30\\p4_summary.parquet") |>
  collect() |>
  filter(p %in% anccr_params, events %in% c(2, 3)) |>
  group_by(p, events, to) |>
  reframe(mDA = mean(mDA)) |>
  pivot_wider(names_from = c(events, to), values_from = mDA, names_glue = "e{events}_{to}") |>
  mutate(mean_a1 = e2_0 / e2_1, mean_a2 = e3_0 / e3_1) |>
  left_join(param_table) -> anccr_rr_p4_summary

anccr_rr_p4_summary |>
  select(mean_a1, mean_a2) |>
  mutate(mean_a1 = round(mean_a1, 2), mean_a2 = round(mean_a2, 2)) |>
  distinct() -> anccr_p4_reduced

power_grid(anccr_p4_reduced, 0.06, lower_limit = 0, upper_limit = 3) -> anccr_p4_power_grid
power_grid(anccr_p4_reduced, 0.12, lower_limit = 0, upper_limit = 3) -> anccr_p4_power_grid_2sd

anccr_rr_p4_summary |>
  left_join(param_table) |>
  filter(w == 1) |>
  select(mean_a1, mean_a2) |>
  mutate(mean_a1 = round(mean_a1, 2), mean_a2 = round(mean_a2, 2)) -> anccr_p4_w1

power_grid(anccr_p4_w1, 0.06, lower_limit = 0, upper_limit = 3) -> anccr_p4_power_grid_w1
power_grid(anccr_p4_w1, 0.12, lower_limit = 0, upper_limit = 3) -> anccr_p4_power_grid_w1_2sd

open_dataset("td_p4_summary.parquet") |>
  collect() |>
  filter(events %in% c(2, 3)) |>
  group_by(alpha, gamma, events, to) |>
  reframe(mDA = mean(rpe)) |>
  pivot_wider(names_from = c(events, to), values_from = mDA, names_glue = "e{events}_{to}") |>
  mutate(mean_a1 = e2_0 / e2_1, mean_a2 = e3_0 / e3_1) |> left_join(td_params) |> filter(p%in%td_params) -> td_rr_p4_summary

td_rr_p4_summary |>
  select(mean_a1, mean_a2) |>
  mutate(mean_a1 = round(mean_a1, 2), mean_a2 = round(mean_a2, 2)) |>
  distinct() -> td_p4_reduced

power_grid(td_p4_reduced, 0.06, lower_limit = 0, upper_limit = 3) -> td_p4_power_grid
power_grid(td_p4_reduced, 0.12, lower_limit = 0, upper_limit = 3) -> td_p4_power_grid_2sd

anccr_p4_power_grid |> mutate(model = "ANCCR Full", sd = 1) -> anccr_p4_power_grid
anccr_p4_power_grid_2sd |> mutate(model = "ANCCR Full", sd = 2) -> anccr_p4_power_grid_2sd
td_p4_power_grid |> mutate(model = "TD", sd = 1) -> td_p4_power_grid
td_p4_power_grid_2sd |> mutate(model = "TD", sd = 2) -> td_p4_power_grid_2sd
anccr_p4_power_grid_w1 |> mutate(model = "ANCCR Prospective", sd = 1) -> anccr_p4_power_grid_w1
anccr_p4_power_grid_w1_2sd |> mutate(model = "ANCCR Prospective", sd = 2) -> anccr_p4_power_grid_w1_2sd

bind_rows(anccr_p4_power_grid, anccr_p4_power_grid_2sd, td_p4_power_grid, td_p4_power_grid_2sd, anccr_p4_power_grid_w1, anccr_p4_power_grid_w1_2sd) -> p4_power_grid
