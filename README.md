# LimnoSES.jl
A limnological social-ecological system hybrid.

[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://libbum.github.io/LimnoSES.jl/dev)
[![CI](https://github.com/Libbum/LimnoSES.jl/workflows/CI/badge.svg)](https://github.com/Libbum/LimnoSES.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/Libbum/LimnoSES.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Libbum/LimnoSES.jl)

Currently under active development and will be prone to major breaking changes.

## An example model run

```julia
using LimnoSES
using Plots

model = initialise(;
    experiment = Experiment(
        policy = Decision(
            target = managed_clear_eutrophic,
            objectives = objectives(objective(min_time), objective(min_cost)),
        ),
        identifier = "optim",
        nutrient_series = Constant(),
    ),
    lake_setup = lake_initial_state(S1, Martin),
    municipalities = Dict(
        "main" => (
            Governance(
                houseowner_type = Introverted(),
                interventions = planner(plan(Planting, 1:20), plan(Trawling, 1:20)),
                policies = policy(scan(Planting), scan(Trawling)),
            ),
            100,
        ),
    ),
)

_, data = run!(model, agent_step!, model_step!, 100; mdata = [nutrients])

discrete = model.lake.sol(0:12:365*100)

plot(discrete; labels = ["Bream" "Pike" "Vegetation"], xticks = (0:365*5:365*100, 0:5:100))
```
