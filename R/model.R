suppressPackageStartupMessages({
  library(dplyr)
  library(ompr)
  library(ompr.roi)
  library(ROI)
  library(ROI.plugin.highs)
  library(tidyr)
})

scenario_data <- function() {
  demand <- tibble(
    week = 1:26,
    diagnostic = c(
      230, 235, 225, 230, 240, 245, 280, 295, 300, 285, 240, 235, 230,
      225, 230, 235, 240, 245, 250, 245, 240, 235, 230, 230, 235, 230
    ),
    therapeutic = c(
      145, 145, 150, 150, 155, 160, 168, 176, 182, 188, 190, 192, 188,
      195, 187, 182, 178, 172, 168, 165, 162, 158, 155, 152, 150, 148
    ),
    staff_available = c(
      520, 515, 525, 520, 530, 525, 490, 480, 485, 500, 510, 515, 520,
      525, 530, 525, 520, 480, 470, 475, 500, 510, 515, 520, 525, 530
    )
  )

  rooms <- tibble(
    room = 1:10,
    size = c(rep("Small", 3), rep("Medium", 4), rep("Large", 3)),
    diagnostic_capacity = c(rep(60, 3), rep(120, 4), rep(180, 3)),
    therapeutic_capacity = c(rep(30, 3), rep(60, 4), rep(120, 3)),
    setup_cost = c(rep(15000, 3), rep(20000, 4), rep(25000, 3)),
    allocation_cost = c(rep(180, 3), rep(200, 4), rep(220, 3))
  )

  list(demand = demand, rooms = rooms)
}

validate_scenario <- function(scenario) {
  stopifnot(nrow(scenario$demand) == 26)
  stopifnot(nrow(scenario$rooms) == 10)
  stopifnot(all(scenario$demand$diagnostic + scenario$demand$therapeutic <= scenario$demand$staff_available))
  stopifnot(all(scenario$demand$diagnostic >= 0))
  stopifnot(all(scenario$demand$therapeutic >= 0))
  invisible(TRUE)
}

build_model <- function(scenario) {
  validate_scenario(scenario)
  weeks <- scenario$demand$week
  rooms <- scenario$rooms$room
  diagnostic <- scenario$demand$diagnostic
  therapeutic <- scenario$demand$therapeutic
  staff <- scenario$demand$staff_available
  diagnostic_capacity <- scenario$rooms$diagnostic_capacity
  therapeutic_capacity <- scenario$rooms$therapeutic_capacity
  setup_cost <- scenario$rooms$setup_cost
  allocation_cost <- scenario$rooms$allocation_cost

  MIPModel() %>%
    add_variable(x_unavailable[r, w], r = rooms, w = weeks, type = "binary") %>%
    add_variable(x_diagnostic[r, w], r = rooms, w = weeks, type = "binary") %>%
    add_variable(x_therapeutic[r, w], r = rooms, w = weeks, type = "binary") %>%
    add_variable(setup[r, w], r = rooms, w = weeks, type = "binary") %>%
    add_variable(diagnostic_hours[r, w], r = rooms, w = weeks, lb = 0) %>%
    add_variable(therapeutic_hours[r, w], r = rooms, w = weeks, lb = 0) %>%
    add_constraint(
      x_unavailable[r, w] + x_diagnostic[r, w] + x_therapeutic[r, w] == 1,
      r = rooms, w = weeks
    ) %>%
    add_constraint(sum_expr(diagnostic_hours[r, w], r = rooms) == diagnostic[w], w = weeks) %>%
    add_constraint(sum_expr(therapeutic_hours[r, w], r = rooms) == therapeutic[w], w = weeks) %>%
    add_constraint(
      sum_expr(diagnostic_hours[r, w] + therapeutic_hours[r, w], r = rooms) <= staff[w],
      w = weeks
    ) %>%
    add_constraint(
      therapeutic_hours[r, w] <= therapeutic_capacity[r] * x_therapeutic[r, w],
      r = rooms, w = weeks
    ) %>%
    add_constraint(
      diagnostic_hours[r, w] + therapeutic_hours[r, w] <=
        diagnostic_capacity[r] * x_diagnostic[r, w] +
          therapeutic_capacity[r] * x_therapeutic[r, w],
      r = rooms, w = weeks
    ) %>%
    add_constraint(setup[r, 1] >= x_diagnostic[r, 1] + x_therapeutic[r, 1], r = rooms) %>%
    add_constraint(
      setup[r, w] >=
        (x_diagnostic[r, w] + x_therapeutic[r, w]) -
          (x_diagnostic[r, w - 1] + x_therapeutic[r, w - 1]),
      r = rooms, w = weeks[-1]
    ) %>%
    set_objective(
      sum_expr(setup_cost[r] * setup[r, w], r = rooms, w = weeks) +
        sum_expr(
          allocation_cost[r] *
            (diagnostic_capacity[r] * x_diagnostic[r, w] +
              therapeutic_capacity[r] * x_therapeutic[r, w]),
          r = rooms, w = weeks
        ),
      sense = "min"
    )
}

solve_capacity_model <- function(model) {
  solve_model(
    model,
    with_ROI(solver = "highs")
  )
}

extract_solution <- function(result, scenario) {
  room_data <- scenario$rooms
  demand <- scenario$demand

  configuration <- bind_rows(
    get_solution(result, x_diagnostic[r, w]) %>% mutate(mode = "Diagnostic"),
    get_solution(result, x_therapeutic[r, w]) %>% mutate(mode = "Therapeutic"),
    get_solution(result, x_unavailable[r, w]) %>% mutate(mode = "Unavailable")
  ) %>%
    filter(value > 0.5) %>%
    transmute(room = r, week = w, mode)

  diagnostic_hours <- get_solution(result, diagnostic_hours[r, w]) %>%
    transmute(room = r, week = w, diagnostic_hours = value)
  therapeutic_hours <- get_solution(result, therapeutic_hours[r, w]) %>%
    transmute(room = r, week = w, therapeutic_hours = value)
  setups <- get_solution(result, setup[r, w]) %>%
    transmute(room = r, week = w, setup_flag = as.integer(value > 0.5))

  detail <- configuration %>%
    left_join(diagnostic_hours, by = c("room", "week")) %>%
    left_join(therapeutic_hours, by = c("room", "week")) %>%
    left_join(setups, by = c("room", "week")) %>%
    left_join(room_data, by = "room") %>%
    mutate(
      assigned_hours = diagnostic_hours + therapeutic_hours,
      opened_capacity = case_when(
        mode == "Diagnostic" ~ diagnostic_capacity,
        mode == "Therapeutic" ~ therapeutic_capacity,
        TRUE ~ 0
      ),
      utilisation = if_else(opened_capacity > 0, assigned_hours / opened_capacity, 0),
      weekly_capacity_cost = case_when(
        mode == "Diagnostic" ~ allocation_cost * diagnostic_capacity,
        mode == "Therapeutic" ~ allocation_cost * therapeutic_capacity,
        TRUE ~ 0
      ),
      weekly_setup_cost = setup_flag * setup_cost
    ) %>%
    arrange(week, room)

  weekly <- detail %>%
    group_by(week) %>%
    summarise(
      assigned_diagnostic = sum(diagnostic_hours),
      assigned_therapeutic = sum(therapeutic_hours),
      assigned_total = sum(assigned_hours),
      opened_room_capacity = sum(opened_capacity),
      setup_events = sum(setup_flag),
      .groups = "drop"
    ) %>%
    left_join(demand, by = "week") %>%
    mutate(
      unused_staff_capacity = staff_available - assigned_total,
      unused_room_capacity = opened_room_capacity - assigned_total,
      room_utilisation = assigned_total / opened_room_capacity
    )

  costs <- detail %>%
    summarise(
      setup_cost = sum(weekly_setup_cost),
      allocation_cost = sum(weekly_capacity_cost),
      total_cost = setup_cost + allocation_cost
    )

  list(detail = detail, weekly = weekly, costs = costs)
}
