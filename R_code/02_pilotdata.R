require(tidyverse)
require(arrow)
require(fastFMM)

open_dataset("pilot_data.parquet") |>
  filter(trial_idx < 6000, exp == "OdorLaserFreeWater.mat") |>
  mutate(rew_len = if_else(rew_len < 0.1, "low", "high")) |>
  mutate(trial_idx = floor(trial_idx_lick_adj / 20)) |>
  group_by(mouse, session, trial, rew_len, trial_idx) |>
  summarise(sig = mean(c1)) |>
  filter(between(trial_idx, -30, 150)) -> ex_down

ex_down |>
  group_by(mouse, session, trial) |>
  mutate(max_sig = max(sig)) |>
  group_by(mouse, session) |>
  mutate(ref_sig = mean(max_sig[rew_len == "high"])) |>
  ungroup() |>
  mutate(rsig = sig / ref_sig) |>
  group_by(mouse, rew_len, trial_idx) |>
  reframe(mean_sig = mean(rsig)) |>
  group_by(rew_len, trial_idx) |>
  reframe(msig = mean(mean_sig), sesig = sd(mean_sig) / sqrt(n())) |>
  ggplot() +
  aes(trial_idx, msig, ymin = msig - sesig, ymax = msig + sesig, color = rew_len) +
  geom_line() +
  geom_ribbon(alpha = 0.2) +
  xlim(-30, 150) +
  ylim(0, 1) + theme(legend.position = "none")


# z-score data on every session, using the mean and sd of the period between -30 and -10
# then average by mouse,session,rew_len, trial_idx
# then average by mouse, rew_len, trial_idx
# then average by rew_len, trial_idx
ex_down |>
  group_by(mouse, session) |>
  mutate(m0 = mean(sig[trial_idx < -15]), sd0 = sd(sig[trial_idx < -15])) |>
  mutate(norm_sig = (sig - m0) / sd0) |>
  ungroup() |>
  group_by(mouse, session, rew_len, trial_idx) |>
  summarise(norm_sig = mean(norm_sig)) |>
  ungroup() |>
  group_by(mouse, rew_len, trial_idx) |>
  summarise(norm_sig = mean(norm_sig)) |>
  ungroup() |>
  group_by(rew_len, trial_idx) |>
  summarise(msig = mean(norm_sig), sdnorm_sig = sd(norm_sig) / sqrt(n())) |>
  ungroup() |>
  ggplot() +
  aes(trial_idx*50/1000, msig, ymin = msig - sdnorm_sig, ymax = msig + sdnorm_sig, color = rew_len) +
  geom_line() +
  geom_ribbon(alpha = 0.2) +
  theme_cowplot(font_size=9) +
  xlab("Time from first lick (s)") +
  ylab("GRABDA3m signal (z-scored)") +
  theme(legend.position = 'bottom')-> pilot_data_plot

##save plot 36mm wide, 61 mm high
ggsave("pilot_data_plot.pdf", pilot_data_plot, width = 36, height = 61, units = "mm")



ex_data <- open_dataset(r"(F:\ModelData\01-2024-RR\pilot_data_proper\ex_data_new.parquet)")

ex_data |>
  filter(min_lick_time < 1.5, exp == "OdorLaserFreeWater.mat") |>
  filter(between(trial_idx_lick_adj, -500, 3000)) |>
  mutate(rew_len = if_else(rew_len < 0.1, "low", "high")) |>
  collect() -> ex_data

ex_data |>
  group_by(mouse, session, trial, rew_len) |>
  summarise(max_sig = max(c1)) -> ex_max


ex_max |>
  group_by(rew_len) |>
  summarise(msig = mean(max_sig), sdsig = sd(max_sig)) |>
  ggplot() +
  aes(rew_len, msig, ymin = msig - sdsig, ymax = msig + sdsig) +
  geom_col() +
  geom_errorbar(width = 0.1)

ex_max |>
  group_by(mouse) |>
  mutate(norm_sig = max_sig / mean(max_sig[rew_len == "high"])) |>
  group_by(mouse, rew_len) |>
  summarise(norm_sig = mean(norm_sig)) |>
  group_by(rew_len) |>
  summarise(msig = mean(norm_sig), sdsig = sd(norm_sig)) |>
  ggplot() +
  aes(rew_len, msig, ymin = msig - sdsig, ymax = msig + sdsig) +
  geom_col() +
  geom_errorbar(width = 0.1)

ex_auc |>
  group_by(mouse) |>
  mutate(norm_sig = max_sig / mean(max_sig[rew_len == "high"])) |>
  group_by(mouse, rew_len) |>
  summarise(norm_sig = mean(norm_sig)) |>
  group_by(rew_len) |>
  summarise(msig = mean(norm_sig), sdsig = sd(norm_sig)) |>
  ggplot() +
  aes(rew_len, msig, ymin = msig - sdsig, ymax = msig + sdsig) +
  geom_col() +
  geom_errorbar(width = 0.1)


ex_max |>
  group_by(mouse, session) |>
  mutate(norm_sig = max_sig / mean(max_sig[rew_len == "high"])) |>
  group_by(mouse, rew_len) |>
  summarise(norm_sig = mean(norm_sig)) |>
  group_by(rew_len) |>
  summarise(msig = mean(norm_sig), sdsig = sd(norm_sig)) |>
  ggplot() +
  aes(rew_len, msig, ymin = msig - sdsig, ymax = msig + sdsig) +
  geom_col() +
  geom_errorbar(width = 0.1)

ex_max |>
  group_by(mouse, session, trial < 11) |>
  mutate(norm_sig = max_sig / mean(max_sig[rew_len == "high"])) |>
  group_by(mouse, rew_len) |>
  summarise(norm_sig = mean(norm_sig)) |>
  group_by(rew_len) |>
  summarise(msig = mean(norm_sig), sdsig = sd(norm_sig)) |>
  ggplot() +
  aes(rew_len, msig, ymin = msig - sdsig, ymax = msig + sdsig) +
  geom_col() +
  geom_errorbar(width = 0.1)


ex_data_auc |>
  group_by(mouse, session) |>
  mutate(norm_sig = max_sig / mean(max_sig[rew_len == "high"])) |>
  filter(rew_len == "low") |>
  summarise(norm_sig = mean(norm_sig)) |>
  group_by(mouse) |>
  summarise(norm_sig_mean = mean(norm_sig), norm_sig_sd = sd(norm_sig)) |>
  ggplot() +
  aes(norm_sig_sd) +
  geom_density() +
  xlim(0, 1)


ex_data |>
  group_by(mouse, rew_len) |>
  summarise(msig = mean(max_sig)) |>
  pivot_wider(names_from = rew_len, values_from = msig) |>
  mutate(ratio = high / low) |>
  ungroup() |>
  summarise(msig = mean(ratio), sdsig = sd(ratio)) |>
  ggplot() +
  aes(1, msig, ymin = msig - sdsig, ymax = msig + sdsig) +
  geom_col() +
  geom_errorbar(width = 0.1)

ex_data_auc |>
  group_by(mouse, session, rew_len) |>
  summarise(msig = mean(max_sig)) |>
  pivot_wider(names_from = rew_len, values_from = msig) |>
  mutate(ratio = low / high) |>
  group_by(mouse) |>
  summarise(ratio = mean(ratio)) |>
  ungroup() |>
  summarise(msig = mean(ratio), sdsig = sd(ratio)) |>
  ggplot() +
  aes(1, msig, ymin = msig - sdsig, ymax = msig + sdsig) +
  geom_col() +
  geom_errorbar(width = 0.1)

ex_data |>
  group_by(mouse, session, rew_len, trial < 11) |>
  summarise(msig = mean(max_sig)) |>
  pivot_wider(names_from = rew_len, values_from = msig) |>
  mutate(ratio = low / high) |>
  group_by(mouse) |>
  summarise(sdratio = sd(ratio), ratio = mean(ratio)) |>
  ungroup() |>
  summarise(msig = mean(ratio), sdsig = sd(ratio)) |>
  ggplot() +
  aes(1, msig, ymin = msig - sdsig, ymax = msig + sdsig) +
  geom_col() +
  geom_errorbar(width = 0.1)
