# LimnoSES.jl
A limnological social-ecological system hybrid.

Currently under active development and will be prone to major breaking changes.

[Development Documentation](https://libbum.github.io/LimnoSES.jl/dev/)

## An example model run

```julia
using LimnoSES
using Decisions
using Plots

model = initialise(
    experiment = Experiment(
        identifier = "municipalities",
        objectives = objectives(
            objective(Decisions.min_time),
            objective(Decisions.min_price, 0.5),
        ),
        nutrient_series = Dynamic(),
    ),
    lake_setup = lake_initial_state(X1, Martin),
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
_, data = run!(model, agent_step!, model_step!, 60; mdata = [nutrients])

discrete = model.lake.sol(0:12:365*60)

plot(discrete; labels = ["Bream" "Pike" "Vegetation"], xticks = (0:365*5:365*60, 0:5:60))
```
