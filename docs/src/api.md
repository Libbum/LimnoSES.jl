None of this is final, but some current public facing functions:

```@docs
initialise
planner
plan
```

## NutrientSeries

`NutrientSeries` is an abstract type from which concrete types can be implemented
to describe the dynamics of nutrient introduction to the lake.

```@docs
Constant
Dynamic
TransientUp
TransientDown
```
