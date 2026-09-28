# Healthcare Capacity Optimisation in R

A mixed-integer optimisation model that turns 26 weeks of diagnostic and therapeutic demand into a feasible, cost-minimising plan for 10 treatment rooms.

The business decision is not simply “how much capacity is available?” It is **which room mode should be opened in each week, when setup costs should be incurred, and how demand can be met without breaching clinician capacity**.

## Executive result

| Result | Value |
|---|---:|
| Planning horizon | 26 weeks |
| Rooms | 10 |
| Solver | HiGHS via `ompr` / ROI |
| Presolved constraints | 832 |
| Presolved variables | 1,292 |
| Binary variables after presolve | 774 |
| Total cost | **£2,265,600** |
| Setup cost | £150,000 |
| Capacity-allocation cost | £2,115,600 |
| Reported optimality gap | **0.00883%** |

The model met diagnostic and therapeutic demand in every week, respected available clinician hours and selected exactly one operating mode per room-week.

![Weekly demand and staff capacity](figures/weekly_capacity.png)

## Decision model

Each room-week is assigned one of three modes:

- unavailable;
- diagnostic; or
- therapeutic.

Continuous variables allocate diagnostic and therapeutic hours. Binary setup indicators capture the cost of activating a room in week 1 or reopening it after a period of inactivity.

The objective minimises:

```text
room setup cost + mode-specific weekly capacity cost
```

Subject to:

1. exactly one mode per room-week;
2. all weekly diagnostic demand being met;
3. all weekly therapeutic demand being met;
4. total activity not exceeding clinician availability;
5. therapeutic work occurring only in therapeutic rooms;
6. room allocations not exceeding mode-specific capacity; and
7. setup costs being triggered when capacity is activated.

## Why this is useful

This project demonstrates prescriptive analytics rather than prediction. It makes the operational trade-off explicit: room configurations with more capacity can reduce feasibility risk, but incur higher fixed operating costs. The exported weekly plan lets a manager see demand coverage, unused staff capacity, opened room capacity and setup events.

| Room schedule | Weekly utilisation |
|---|---|
| ![Room mode schedule](figures/room_schedule.png) | ![Utilisation](figures/weekly_utilisation.png) |

## Repository guide

| Path | Purpose |
|---|---|
| `R/model.R` | Scenario data, MILP formulation and solution extraction |
| `R/run_analysis.R` | Reproducible end-to-end run and exports |
| `R/validate_outputs.R` | Headline and feasibility assertions |
| `outputs/` | Weekly plan, room schedule and cost summary |
| `figures/` | Decision-ready visual outputs |
| `tests/` | Structural tests for inputs and saved results |

## Reproduce

Install R 4.4+ and the packages listed in `requirements.R`, then run:

```bash
Rscript requirements.R
Rscript R/run_analysis.R
Rscript tests/test_model.R
```

The optimisation uses the open-source HiGHS solver. It may return another room-level schedule with the same objective because symmetric rooms can produce multiple equivalent optima.

## Improvements over the academic submission

The public version removes interactive `View()` calls, uses project-relative paths, separates formulation from reporting, exports all decision tables, adds automated assertions and keeps the management narrative concise. The underlying formulation and headline result remain aligned with the submitted work.

## Limitations

- Demand and staff availability are treated as known rather than uncertain.
- The objective prices configured capacity, not realised patient waiting or overtime.
- Room types within each size band are symmetric.
- The case is a planning scenario, not a live NHS deployment.

## Author

**Muhammad Ahmed Shoaib** — optimisation, operations analytics and decision support.

