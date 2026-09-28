validate_outputs <- function(solution) {
  tolerance <- 1e-5
  weekly <- solution$weekly
  costs <- solution$costs

  stopifnot(nrow(solution$detail) == 260)
  stopifnot(nrow(weekly) == 26)
  stopifnot(all(abs(weekly$assigned_diagnostic - weekly$diagnostic) < tolerance))
  stopifnot(all(abs(weekly$assigned_therapeutic - weekly$therapeutic) < tolerance))
  stopifnot(all(weekly$assigned_total <= weekly$staff_available + tolerance))
  stopifnot(all(weekly$unused_room_capacity >= -tolerance))
  stopifnot(abs(costs$setup_cost - 150000) < tolerance)
  stopifnot(abs(costs$allocation_cost - 2115600) < tolerance)
  stopifnot(abs(costs$total_cost - 2265600) < tolerance)
  invisible(TRUE)
}

