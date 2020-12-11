Non exported functions can be found here.

```@docs
LimnoSES.type2dict
LimnoSES.nutrient_load!
LimnoSES.active_interventions
```

# Decisions

This module uses [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl) to
set intervention policies that satisfy a number of objectives whilst attempting to reach
a given target.

## Targets

Targets are written in the form of an
[Agents.jl `until`](https://juliadynamics.github.io/Agents.jl/stable/tutorial/#Agents.step!)
function. Any stopping condition is possible and can be user generated. The following
examples are pre-defined:

```@docs
LimnoSES.Decisions.clear_state
```

## Objectives

There is no 'right' way of meeting a target, since we may have multiple objectives to
contend with. Objectives are a function that take `model` as an argument and return a
`Float64`.

Once created, these should be initialised using [`objective`](@ref), since the model
also expects an associated weight.

Pre-defined values:

```@docs
LimnoSES.Decisions.min_time
LimnoSES.Decisions.min_acceleration
LimnoSES.Decisions.min_cost
```

## Runtime

```@docs
LimnoSES.Decisions.make_decision!
```

## Private Functions

```@docs
LimnoSES.Decisions.create_test_model
LimnoSES.Decisions.apply_policies!
LimnoSES.Decisions.update_true_model!
LimnoSES.Decisions.cost
LimnoSES.Decisions.weightedfitness
```
