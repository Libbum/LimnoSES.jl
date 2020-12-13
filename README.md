# LimnoSES.jl
A limnological social-ecological system hybrid.

[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://libbum.github.io/LimnoSES.jl/dev)
[![CI](https://github.com/Libbum/LimnoSES.jl/workflows/CI/badge.svg)](https://github.com/Libbum/LimnoSES.jl/actions?query=workflow%3ACI)

Currently under active development and will be prone to major breaking changes.

## An example model run

```julia
using LimnoSES
using Plots

model = initialise(
    experiment = Experiment(
        identifier = "municipalities",
        objectives = objectives(
            objective(min_time),
            objective(min_cost, 0.5),
        ),
        nutrient_series = Dynamic(),
    ),
    lake_setup = lake_initial_state(X2, Martin),
    municipalities = Dict(
        "main" => (
            Governance(
                houseowner_type = Introverted(),
                interventions = planner(plan(Angling)),
            ),
            100,
        ),
        "little" => (
            Governance(
                houseowner_type = Enforced(),
                interventions = planner(
                    plan(WastewaterTreatment),
                    plan(Planting, 2; rate = 1.0e-3),
                    plan(Trawling, 0:3; rate = 1.3e-3),
                ),
                policies = policy(scan(Planting), scan(Trawling)),
            ),
            10,
        ),
        "another" => (
            Governance(
                houseowner_type = Social(),
                interventions = planner(
                    plan(WastewaterTreatment),
                    plan(Planting, 0:8; rate = 0.9e-3, threshold = 40.0),
                ),
                policies = policy(scan(Planting)),
            ),
            80,
        ),
    ),
)
_, data = run!(model, agent_step!, model_step!, 100; mdata = [nutrients])

discrete = model.lake.sol(0:12:365*100)

plot(discrete; labels = ["Bream" "Pike" "Vegetation"], xticks = (0:365*5:365*100, 0:5:100))
```
