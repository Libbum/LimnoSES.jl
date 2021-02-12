LimnoSES.jl is a dynamical system, agent based model hybrid, focusing on socio-ecological interactions in lake systems.

Powered by the [Agents.jl](https://github.com/JuliaDynamics/Agents.jl) ABM framework and the [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl) ecosystem.

## Quickstart

### Simple Optimisation Campaign

An example run looking at a planting & trawling campaign over 20 years, attempting to flip the lake state from Turbid to Clear with a 100 year time horizon

```julia
using LimnoSES

model = initialise(;
    experiment = Experiment(
        policy = Decision(
            target = clear_state,
            objectives = objectives(objective(min_time), objective(min_cost)),
        ),
        identifier = "Turbid->Clear, constant Nutrients",
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

function assets(model)
    nutrients(model) = model.lake.p.nutrients
    plant_rate(model) = model.lake.p.pv
    trawl_rate(model) = model.lake.p.tb
    return [nutrients, plant_rate, trawl_rate]
end

_, data = run!(model, agent_step!, model_step!, 100; mdata = assets(model))

using Plots

discrete = model.lake.sol(0:12:365*100)

hl = plot(
    discrete;
    labels = ["Bream" "Pike" "Vegetation"],
    xticks = (0:365*5:365*100, 0:5:100),
)
hr = plot([data.plant_rate data.trawl_rate], labels = ["Plant Rate" "Trawl Rate"])
hn = plot(data.nutrients, label = "Nutrients")
l = @layout [a; b c]
plot(hl, hr, hn, layout = l, size = (1000, 700))
```

### Stochastic Distributed Campaign

A 20 year planting campaign, 100 year time horizon and Turbid to Clear target. This time using geometric Brownian motion within the bistable corridor to simulate wending nutrient levels. 10 complete runs, each with 10 projected optimiser calls with new random seeds on the nutrient noise process.
Distributed over as many process as you wish, this example uses one control and 13 workers.

```julia
using Distributed
addprocs(13)
@everywhere begin
    import Pkg
    Pkg.activate(@__DIR__)
end

@everywhere using LimnoSES
@everywhere model = initialise(;
    experiment = Experiment(
        policy = Decision(
            target = clear_state,
            objectives = objectives(objective(min_time), objective(min_cost)),
            opt_replicates = 10,
        ),
        identifier = "noisy_N, Turbid->Clear",
        nutrient_series = Noise(
            GeometricBrownianMotionProcess(0.0, 0.05, 0.0, 2.0),
            1.0,
            2.5,
        ),
    ),
    lake_setup = lake_initial_state(S1, Martin),
    municipalities = Dict(
        "main" => (
            Governance(
                houseowner_type = Introverted(),
                interventions = planner(plan(Planting, 1:20)),
                policies = policy(scan(Planting)),
            ),
            100,
        ),
    ),
)

@everywhere function assets(model)
    nutrients(model) = model.lake.p.nutrients
    plant_rate(model) = model.lake.p.pv
    trawl_rate(model) = model.lake.p.tb
    discrete(model) = model.lake.sol(
        (model.year > 1 ? 365 * (model.year - 1) + 36.5 : 0):36.5:365*model.year,
    )
    return [nutrients, plant_rate, trawl_rate, discrete]
end

reps = 10
years = 100
_, data = replicates(model, agent_step!, model_step!, years, reps; mdata = assets(model))

using Plots, Statistics

discrete = LimnoSES.OrdinaryDiffEq.VectorOfArray([
    cat(
        collect(Iterators.flatten(
            d.u
            for
            d in
            LimnoSES.DataFrames.filter(
                [:replicate, :step] => (r, s) -> r == i && s != 0,
                data,
            ).discrete
        ))...,
        dims = 2,
    ) for i in 1:reps
])
t = 0:36.5:365*years

hl = plot(
    t,
    mean(discrete[1, :, :], dims = 2),
    ribbon = std(discrete[1, :, :], dims = 2),
    label = "Bream",
    linewidth = 2,
    xticks = (0:365*5:365*years, 0:5:years),
)
plot!(
    hl,
    t,
    mean(discrete[2, :, :], dims = 2),
    ribbon = std(discrete[2, :, :], dims = 2),
    label = "Pike",
    linewidth = 2,
)
plot!(
    hl,
    t,
    mean(discrete[3, :, :], dims = 2),
    ribbon = std(discrete[3, :, :], dims = 2),
    label = "Vegetation",
    linewidth = 2,
)

plant_rate = reshape(data.plant_rate, (years + 1, reps))
hr = plot(
    mean(plant_rate, dims = 2),
    ribbon = std(plant_rate, dims = 2),
    label = "Plant Rate",
    linewidth = 2,
    color = palette(:default)[3],
)
nut = reshape(data.nutrients, (years + 1, reps))
hn = plot(
    mean(nut, dims = 2),
    ribbon = std(nut, dims = 2),
    label = "Nutrients",
    linewidth = 2,
)
l = @layout [a; b c]
plot(hl, hr, hn, layout = l, size = (1000, 700))
```
