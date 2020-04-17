module LimnoSES

using Agents, Parameters, StatsBase

include("config.jl")
include("lake_state.jl")
include("coupling.jl")
include("initialise.jl")
include("evolve.jl")
include("reporting.jl")

end # module

