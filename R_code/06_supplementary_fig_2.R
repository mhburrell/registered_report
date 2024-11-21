# Extended Data Figure 2: Variance

ct |>
  mutate(PRC_diff = abs(PRC_gt - PRC), SRC_diff = abs(SRC_gt - SRC)) |>
  group_by(M, p, rep, ephase) |>
  summarise(sum_PRC = sum(PRC_diff), sum_SRC = sum(SRC_diff)) |>
  group_by(p, rep, ephase) |>
  summarise(var_PRC = mean(sum_PRC), var_SRC = mean(sum_SRC)) |>
  group_by(p, ephase) |>
  summarise(mean_var_PRC = mean(var_PRC), mean_var_SRC = mean(var_SRC)) |>
  collect() -> withinrep_variance

withinrep_variance |>
  ungroup() |>
  left_join(param_table) |>
  group_by(alpha_anccr) |>
  reframe(mean_var_PRC = mean(mean_var_PRC)) |>
  ggplot() +
  aes(alpha_anccr, mean_var_PRC) +
  geom_point()+ylim(0,25)+geom_line()

withinrep_variance |>
  ungroup() |>
  left_join(param_table) |>
  group_by(alpha_anccr) |>
  reframe(mean_var_SRC = mean(mean_var_SRC)) |>
  ggplot() +
  aes(alpha_anccr, mean_var_SRC) +
  geom_point()+ylim(0,25)+geom_line()

ct |>
  mutate(PRC_diff = abs(PRC_gt - PRC), SRC_diff = abs(SRC_gt - SRC)) |>
  group_by(M, p, rep, ephase) |>
  summarise(sum_PRC = sum(PRC_diff), sum_SRC = sum(SRC_diff)) |>
  group_by(p, ephase) |>
  summarise(var_PRC = var(sum_PRC), var_SRC = var(sum_SRC)) |> collect() -> withinrep_variance


ct |>
  mutate(PRC_diff = abs(PRC_gt - PRC), SRC_diff = abs(SRC_gt - SRC)) |>
  group_by(M, p, rep, ephase) |>
  summarise(sum_PRC = sum(PRC_diff), sum_SRC = sum(SRC_diff)) |> 
  group_by(p,ephase,rep) |>
  summarise(mean_PRC = var(sum_PRC), mean_SRC = var(sum_SRC)) |>
  group_by(p,ephase) |>
  summarise(mean_var_PRC = var(mean_PRC), mean_var_SRC = var(mean_SRC)) |> collect() -> betweenrep_variance

betweenrep_variance |> left_join(param_table) |> ggplot()+aes(alpha_anccr,mean_var_PRC)+geom_point()


rr_ANCCR_extract |> filter(Y==1) |> mutate(ephase = as.integer(cut(M,breaks = c(-Inf,12000,22000,Inf),labels=FALSE))) |> collect() -> banccr
vanccr |> group_by(p,rep,ephase) |> reframe(vanc = sum(vanc)) |> left_join(param_table) |> ggplot()+aes(theta,vanc,group = theta)+geom_violin()+ylim(0,10)

#double check this:
ct |> mutate(PRC_diff = abs(PRC_gt-PRC), SRC_diff = abs(SRC_gt-SRC)) |> 
  group_by(M,p,rep,ephase) |>
  summarize(PRC_diff = sum(PRC_diff), SRC_diff = sum(SRC_diff)) |>
  group_by(ephase,p,rep) |>
  summarize(PRC_diff = mean(PRC_diff), SRC_diff = mean(SRC_diff)) |> 
  ungroup() |>
  collect() -> ct_diff_withinrep

ct |> mutate(PRC_diff = abs(PRC_gt-PRC), SRC_diff = abs(SRC_gt-SRC)) |> 
  group_by(X,Y,p,ephase,rep) |>
  summarize(var_PRC_diff = sd(PRC_diff), var_SRC_diff = sd(SRC_diff)) |>
  group_by(X,Y,p,ephase) |> 
  summarize(var_PRC_diff = mean(var_PRC_diff), var_SRC_diff = mean(var_SRC_diff)) |>
  ungroup() |>
  collect() -> ct_diff_withinphase

##

withinrep_variance |>
  left_join(param_table) |>
  group_by(alpha_anccr) |>
  reframe(mean_PRC = mean(var_PRC), mean_SRC = mean(var_SRC), sdPRC = sd(var_PRC), sdSRC = sd(var_SRC)) -> withinrep_variance_sum

withinrep_variance_sum |>
  ggplot() +
  aes(x = factor(alpha_anccr), y = mean_PRC) +
  geom_col() +
  theme_cowplot() -> panel_A

withinrep_variance_sum |>
  ggplot() +
  aes(x = factor(alpha_anccr), y = mean_SRC) +
  geom_col() +
  theme_cowplot() -> panel_B

betweenrep_variance |>
  left_join(param_table) |>
  group_by(alpha_anccr) |>
  reframe(mean_PRC = mean(mean_var_PRC), mean_SRC = mean(mean_var_SRC), sdPRC = sd(mean_var_PRC), sdSRC = sd(mean_var_SRC)) -> betweenrep_variance_sum

betweenrep_variance_sum |>
  ggplot() +
  aes(x = factor(alpha_anccr), y = mean_PRC) +
  geom_col() +
  theme_cowplot() -> panel_C

betweenrep_variance_sum |>
  ggplot() +
  aes(x = factor(alpha_anccr), y = mean_SRC) +
  geom_col() +
  theme_cowplot() -> panel_D

vanccr |>
  left_join(param_table) |>
  filter(vanc < (1000)) |>
  group_by(theta) |>
  reframe(var_anccr = mean(vanc)) |>
  ggplot() +
  aes(factor(theta), var_anccr) +
  geom_col() +
  theme_cowplot() -> panel_E

vanccr |>
  left_join(param_table) |>
  filter(vanc < (1000)) |>
  group_by(Tratio) |>
  reframe(var_anccr = mean(vanc)) |>
  ggplot() +
  aes(factor(Tratio), var_anccr) +
  geom_col() +
  theme_cowplot() -> panel_F


plot_grid(panel_A, panel_B, panel_C, panel_D, panel_E, panel_F, ncol = 2,align = "hv",axis = "tblr",labels = c("A", "B", "C", "D", "E", "F")) -> figs2

ggsave("figs2.pdf", figs2, width = 8, height = 12, units = "in")

## data read in:

open_dataset("G:\\Model Data\\ANCCR RR\\cont\\s10_1")
open_dataset("G:\\Model Data\\ANCCR RR\\cont\\rr_b6_30_cont") |> to_duckdb(con = con, table_name = "rr_cont") -> rr_cont
read_parquet("G:\\Model Data\\ANCCR RR\\cont\\mt_dist2\\b6_iti30_100x.parquet") -> experiment
read_parquet("G:\\Model Data\\ANCCR RR\\cont\\rr_cont_gt_fixed.parquet") -> rr_cont_gt

open_dataset("G:\\Model Data\\ANCCR RR\\cont\\rr_cont_extract.parquet") |> to_duckdb(con = con, table_name = "rr_cont_extract") -> rr_cont_extract
open_dataset("G:\\Model Data\\ANCCR RR\\cont\\rr_ANCCR_extract.parquet") |> to_duckdb(con = con, table_name = "rr_ANCCR_extract") -> rr_ANCCR_extract

rr_cont_extract |>
  mutate(PRC_diff = abs(PRC - PRC_gt), SRC_diff = abs(SRC - SRC_gt)) |>
  group_by(ephase, p, X, Y, rep) |>
  summarize(mean_PRC_diff = mean(PRC_diff), mean_SRC_diff = mean(SRC_diff), sd_PRC_diff = sd(PRC_diff), sd_SRC_diff = sd(SRC_diff)) |>
  ungroup() |>
  collect() -> rr_cont_extract_summary

rr_cont_extract |>
  mutate(PRC_diff = abs(PRC - PRC_gt), SRC_diff = abs(SRC - SRC_gt)) |>
  group_by(ephase, p, X, Y, rep) |>
  summarize(mean_PRC_diff = mean(PRC_diff), mean_SRC_diff = mean(SRC_diff), sd_PRC_diff = sd(PRC_diff), sd_SRC_diff = sd(SRC_diff)) |>
  group_by(ephase, p, rep) |>
  select(-X, -Y) |>
  summarise_all(sum) |>
  ungroup() |>
  collect() -> rr_cont_extract_summary2

rr_cont |>
  filter(between(M, 9500, 10000) | between(M, 19500, 20000) | between(M, 29500, 30000)) |>
  select(X, Y, M, ANCCR, p, rep) |>
  mutate(X = as.integer(X), Y = as.integer(Y), M = as.integer(M), p = as.integer(p), rep = as.integer(rep)) |>
  collect() -> larger_collect
