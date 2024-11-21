anccr_sim |> filter(p%in%anccr_params) |> group_by(p,ephase,events,rep) |> 
  summarise(mean_DA = mean(DA)) |>
  group_by(p,ephase,events) |> 
  summarise(mean_DA = mean(mean_DA)) |>
  pivot_wider(names_from = c(ephase, events), values_from = mDA, names_glue = "e{events}_p{ephase}") |>
  group_by(p) |>
  mutate(mean_a1 = mean(e2_p3 / e2_p1), mean_a2 = mean(e3_p2 / e3_p3)) |>
  filter() |>
  select(-starts_with("e")) |>
  collect() -> anccr_sim_summary

anccr_sim_summary |>
 left_join(param_table) |> 
  filter(p==1) -> full_prospective_anccr_sim_summary

td_sim |> group_by(alpha,gamma,events,rep) |>
  summarise(mean_DA = mean(RPE)) |>
  group_by(alpha,gamma,events) |>
  summarise(mean_DA = mean(mean_DA)) |>
  pivot_wider(names_from = events, values_from = mean_DA, names_prefix = "e") |>
  mutate(mean_a1 = e2 / e0, mean_a2 = e3 / e1) |>
  select(-starts_with("e")) |>
  collect() |> left_join(td_params) |> filter(p%in%td_params) -> td_sim_summary
  
anccr_sim_summary |>
  ungroup() |>
  mutate(mean_a1 = round(mean_a1, 2), mean_a2 = round(mean_a2, 2)) |>
  select(-p, -n) |>
  distinct() -> anccr_sim_summary_rounded

full_prospective_anccr_sim_summary |>
  ungroup() |>
  mutate(mean_a1 = round(mean_a1, 2), mean_a2 = round(mean_a2, 2)) |>
  select(-p, -n) |>
  distinct() -> full_prospective_anccr_sim_summary_rounded


power_grid(td_rep, 0.06, lower_limit = -1, upper_limit = 4) |> mutate(sd_input = 0.06, model = 'TD') -> rt_td_rep
power_grid(anccr_sim_summary_rounded, 0.06, lower_limit = -1, upper_limit = 4) |> mutate(sd_input = 0.06, model = 'ANCCR') -> rt_anccr_rep
power_grid(full_prospective_anccr_sim_summary_rounded,0.06, lower_limit = -1, upper_limit = 4) |> mutate(sd_input = 0.06, model = 'Prospective ANCCR') -> rt_full_prospective_anccr_rep

power_grid(td_rep, 0.12, lower_limit = -1, upper_limit = 4) |>
  mutate(sd_input = 0.12, model = 'TD') |>
  bind_rows(rt_td_rep) -> rt_td_rep

power_grid(anccr_sim_summary_rounded, 0.12, lower_limit = -1, upper_limit = 4) |>
  mutate(sd_input = 0.12, model = 'ANCCR') |>
  bind_rows(rt_anccr_rep) -> rt_anccr_rep

power_grid(full_prospective_anccr_sim_summary_rounded, 0.12, lower_limit = -1, upper_limit = 4) |>
  mutate(sd_input = 0.12, model='Prospective ANCCR') |>
  bind_rows(rt_full_prospective_anccr_rep) -> rt_full_prospective_anccr_rep

bind_rows(rt_td_rep, rt_anccr_rep, rt_full_prospective_anccr_rep) |>
  filter(max_mn > 9.9) |>
  ggplot() +
  aes(t1, t2, fill = model) +
  geom_tile() +
  facet_grid(sd_input~.) +
  xlim(-1, 3) +
  ylim(-1, 3) +
  theme_cowplot(font_size = 8) +
  theme(legend.position = "none", strip.background = element_blank(),strip.text = element_blank()) -> hypothesis_fig