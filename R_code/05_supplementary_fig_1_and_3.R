#Supplementary Fig 1 and 3

open_dataset("published_param_sim.parquet") |> to_duckdb(con = con, table_name = "publishdata") -> pbd
open_dataset("G:\\Backup\\20241010\\mt_dist2\\b6_iti30_100x.parquet") |> to_duckdb(con = con, table_name = "experiment") -> experiment

pbd |>
  left_join(experiment) |>
  filter(ephase < 4, events %in% c(2, 3)) |>
  group_by(p, rep, events, ephase) |>
  slice_max(n = 25, order_by = times) |>
  collect() -> df

df |>
  na.omit() |> 
  group_by(p, events, ephase, rep) |>
  reframe(mDA = mean(DA)) |>
  mutate(ref_ephase = if_else(events == 2, 1, 3)) |>
  group_by(p, events, rep) |>
  mutate(nDA = mDA / mean(mDA[ephase == ref_ephase])) |>
  group_by(p, events, ephase) |>
  reframe(mean_DA = mean(nDA), sd_DA = sd(nDA)) -> df_sum

df_sum |>
  filter(p < 10,) |>
  ggplot() +
  aes(ephase, mean_DA, ymin = mean_DA - sd_DA, ymax = mean_DA + sd_DA, fill = factor(events)) +
  geom_col(width=0.618) +
  geom_errorbar(width = 0.25) +
  facet_nested_wrap(~p+events,scales='free_y',ncol=4)+
  theme_cowplot() +
  theme(legend.position = "none") -> figs1

ggsave('figs1.pdf', figs1, width = 8, height = 8, units = "in")

experiment |>
  filter(ephase == 4) |>
  group_by(rep) |>
  mutate(to = if_else(lag(events) == 7, 1, 0)) |>
  filter(!is.na(to)) |>
  filter(events %in% c(2, 3)) |>
  group_by(events, rep, to) |>
  slice_max(n = 25, order_by = times) -> experiment4_extract

experiment4_extract |>
  left_join(pbd) |>
  collect() -> df4

df4 |>
  group_by(p, events, rep, to) |>
  reframe(mDA = mean(DA)) |>
  pivot_wider(names_from = to, names_prefix = "to", values_from = mDA) |>
  mutate(fold_increase = to0 / to1) |>
  group_by(p, events) |>
  reframe(mean_fold_increase = median(fold_increase), sd_increase = sd(fold_increase)) -> df4_sum

df4_sum |>
  filter(p<10) |> 
  ggplot()+
  aes(p,mean_fold_increase,ymin= mean_fold_increase - sd_increase, ymax = mean_fold_increase + sd_increase, fill = factor(events))+
  geom_col()+
  geom_errorbar(width = 0.25)+
  facet_grid(events~.)+
  theme_cowplot()+
  theme(legend.position = "none")+ylim(-1,5)+scale_x_continuous(breaks = seq(1,9)) -> figs3

ggsave('figs3.pdf', figs3, width = 8, height = 5, units = "in")
