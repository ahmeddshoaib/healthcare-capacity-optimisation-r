source("R/model.R")
source("R/validate_outputs.R")

scenario <- scenario_data()
validate_scenario(scenario)

stopifnot(sum(scenario$demand$diagnostic) == 6340)
stopifnot(sum(scenario$demand$therapeutic) == 4361)
stopifnot(all(scenario$rooms$diagnostic_capacity >= scenario$rooms$therapeutic_capacity))

required_outputs <- c(
  "outputs/room_week_plan.csv",
  "outputs/weekly_capacity_plan.csv",
  "outputs/cost_summary.csv"
)
stopifnot(all(file.exists(required_outputs)))

saved_costs <- read.csv("outputs/cost_summary.csv")
stopifnot(saved_costs$total_cost == 2265600)
stopifnot(saved_costs$setup_cost == 150000)
stopifnot(saved_costs$allocation_cost == 2115600)

message("ALL STRUCTURAL AND SAVED-RESULT TESTS PASSED")
