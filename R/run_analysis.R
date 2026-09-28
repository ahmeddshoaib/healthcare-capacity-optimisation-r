suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

source("R/model.R")

dir.create("outputs", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

scenario <- scenario_data()
model <- build_model(scenario)
result <- solve_capacity_model(model)
solution <- extract_solution(result, scenario)

write_csv(solution$detail, "outputs/room_week_plan.csv")
write_csv(solution$weekly, "outputs/weekly_capacity_plan.csv")
write_csv(solution$costs, "outputs/cost_summary.csv")

capacity_plot <- solution$weekly %>%
  select(week, diagnostic, therapeutic, staff_available) %>%
  pivot_longer(-week, names_to = "series", values_to = "hours") %>%
  ggplot(aes(week, hours, colour = series)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.7) +
  scale_colour_manual(
    values = c(diagnostic = "#1f77b4", therapeutic = "#d62728", staff_available = "#2f855a"),
    labels = c(diagnostic = "Diagnostic demand", therapeutic = "Therapeutic demand", staff_available = "Staff available")
  ) +
  labs(x = "Week", y = "Hours", colour = NULL, title = "Demand and clinician capacity") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
ggsave("figures/weekly_capacity.png", capacity_plot, width = 10, height = 5.5, dpi = 180)

utilisation_plot <- ggplot(solution$weekly, aes(week, room_utilisation)) +
  geom_col(fill = "#5b21b6") +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "#991b1b") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(x = "Week", y = "Opened-room utilisation", title = "Weekly utilisation of configured room capacity") +
  theme_minimal(base_size = 12)
ggsave("figures/weekly_utilisation.png", utilisation_plot, width = 10, height = 5.5, dpi = 180)

room_schedule_plot <- solution$detail %>%
  mutate(mode = factor(mode, levels = c("Unavailable", "Diagnostic", "Therapeutic"))) %>%
  ggplot(aes(week, factor(room), fill = mode)) +
  geom_tile(colour = "white", linewidth = 0.35) +
  scale_fill_manual(values = c(Unavailable = "#d1d5db", Diagnostic = "#2563eb", Therapeutic = "#dc2626")) +
  scale_x_continuous(breaks = seq(1, 26, by = 2)) +
  labs(x = "Week", y = "Room", fill = NULL, title = "Optimised room-mode schedule") +
  theme_minimal(base_size = 12) +
  theme(panel.grid = element_blank(), legend.position = "bottom")
ggsave("figures/room_schedule.png", room_schedule_plot, width = 10, height = 5.5, dpi = 180)

source("R/validate_outputs.R")
validate_outputs(solution)

print(solution$costs)
message("ANALYSIS COMPLETED: all validation checks passed")

