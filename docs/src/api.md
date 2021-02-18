None of this is final, but some current public facing functions:

```@docs
initialise
lake_initial_state
planner
plan
policy
scan
objectives
objective
```

## NutrientSeries

`NutrientSeries` is an abstract type from which concrete types can be implemented
to describe the dynamics of nutrient introduction to the lake.

```@docs
Constant
Dynamic
TransientUp
TransientDown
Noise
```


# Decisions

This system uses [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl) to
set intervention policies that satisfy a number of objectives whilst attempting to reach
a given target.

```@docs
LimnoSES.make_decision!
```

## Targets

Targets are written in the form of an
[Agents.jl `until`](https://juliadynamics.github.io/Agents.jl/stable/tutorial/#Agents.step!)
function. Any stopping condition is possible and can be user generated, although there
**must** be a hard stop at some point in the future. `s == 100 && return true` is the
default. The following
examples are pre-defined:

```@docs
LimnoSES.clear_state
LimnoSES.managed_clear_eutrophic
```

## Objectives

There is no 'right' way of meeting a target, since we may have multiple objectives to
contend with. Objectives are a function that take `model` as an argument and return a
`Float64`.

Once created, these should be initialised using [`objective`](@ref), since the model
also expects an associated weight.

Pre-defined values:

```@docs
LimnoSES.min_time
LimnoSES.min_acceleration
LimnoSES.min_cost
LimnoSES.appropreate_vegetation
```

