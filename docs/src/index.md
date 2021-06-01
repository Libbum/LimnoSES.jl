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

using Plots, Statistics, DataFrames

discrete = LimnoSES.OrdinaryDiffEq.VectorOfArray([
    cat(
        collect(Iterators.flatten(
            d.u
            for
            d in
            DataFrames.filter(
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

## New to Julia

If you've never used Julia before there are a few things you will need to do to get LimnoSES running.

### Install Julia

First, you'll need the Julia runtime. Install the version for your operating system from [this link](https://julialang.org/downloads/). You'll want the current stable release (v1.6.x at time of writing).

### Adding LimnoSES

Now you'll need to add the LimnoSES package to your system. Open the Julia REPL (short for Read-eval-print loop: it's the Julia command line). On linux and mac systems you can type `julia` at a prompt. For windows you can probably do the same or click an icon.

It's nice to do this from a specific directory you want to work in, so if you're using a prompt: first make one, `cd` into it and then start `julia`. Starting from an icon, try `cd("working/directory/path")`. You can use `pwd()` to make sure you're in the right place.

Now press `]` to get into the REPL's package mode - you should see a `(@v1.6) pkg>` prompt. We're going to create a new project which is called whatever you named your folder.
Say your folder was called `shallow_lake`, what we want to do at this prompt is type `activate .`. Now your prompt looks like: `(shallow_lake) pkg>`.

Since LimnoSES is in development, we add it like this:

`add https://github.com/Libbum/LimnoSES.jl`

In the near future it will be simpler, just `add LimnoSES`, but not right away.

Once the install is sorted, you can press backspace to get back to the green `julia>` prompt and type `using LimnoSES`. If all goes well you're ready!

Now you can go through the [Quickstart](@ref) section.
