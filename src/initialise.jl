export initialise, plan, planner

"""
    initialise()

Returns a populated model initialised and ready to run.
"""
function initialise(;
    griddims = (25, 25),
    experiment = Experiment(),
    municipalities = Dict("main" => (Governance(), 100)),
    lake_setup = lake_initial_state(Clear, Martin),
)
    @assert prod(griddims) >=
            sum(last(v) for v in values(municipalities)) + length(municipalities) "Total agents (municipalities + households) cannot be greater than the grid size"

    lake_state, lake_parameters = lake_setup
    prob =
        OrdinaryDiffEq.ODEProblem(lake_dynamics!, lake_state, (0.0, Inf), lake_parameters)

    space = GridSpace(griddims, moore = true)
    properties = type2dict(experiment)
    merge!(properties, type2dict(Outcomes(); prefix = "outcomes"))
    push!(
        properties,
        :lake => OrdinaryDiffEq.init(prob, OrdinaryDiffEq.Tsit5()),
        :year => 0,
        :init_nutrients => lake_parameters.nutrients,
        :init_pike_mortality => lake_parameters.mp,
    )
    model = ABM(
        Union{Individual,Municipality},
        space;
        properties = properties,
        scheduler = by_type((Individual, Municipality), true),
        warn = false,
    )

    total_houses = sum(last(m) for m in values(municipalities))
    real_estate_x = 1
    for (name, (gov, houses)) in municipalities
        #TODO: Do a proper voronoi partition, not this primitive segregation
        juristiction_x = Int(round(first(griddims) * (houses / total_houses)) - 1) # Separation of municipalities in x
        # Place Municipality headquarters in the middle of its juristiction
        municipality_id = nextid(model)
        municipality_pos = (
            Int(round((juristiction_x / 2) + real_estate_x)),
            Int(round(last(griddims) / 2)),
        )
        municipality = Municipality(
            municipality_id,
            municipality_pos,
            name,
            gov.information,
            gov.legislation,
            gov.budget,
            gov.budget_σ,
            gov.regulate,
            gov.respond_direct,
            gov.threshold_variable,
            gov.interventions,
            gov.anticipatory_governance_interest,
            gov.timing_tension,
            gov.agents_uniform,
            gov.action_method,
            gov.willingness_to_upgrade,
            gov.tolerance_level_affectors,
            gov.neighbor_distance,
            houses,
            0,
        )
        add_agent_pos!(municipality, model)
        # Place houses within municipality juristiction
        for _ in 1:houses
            pos = (
                rand(real_estate_x:min(real_estate_x + juristiction_x, first(griddims))),
                rand(1:last(griddims)),
            )
            while !isempty(Agents.coord2vertex(pos, model), model) ||
                  pos == municipality_pos
                pos = (
                    rand(real_estate_x:(real_estate_x + juristiction_x)),
                    rand(1:last(griddims)),
                )
            end
            compliance = gov.agents_uniform ? rand() : gov.willingness_to_upgrade
            # TODO: Introduce an Engagement builder for agents.
            house =
                Individual(nextid(model), pos, Dict(:HouseOwner => HouseOwner(compliance, 0.0, false, false, 0, municipality_id)))
            add_agent_pos!(house, model)
        end
        real_estate_x += juristiction_x
    end
    return model
end

## Intervention planner

"""
    planner(plan(Angling))
    planner(plan(Planting; rate=5e-3),
            plan(Trawling, 1:3))

Provides a complete schedule of interventions for a [Municipality](@ref). Must
be used in conjunction with [`plan`](@ref).
"""
function planner(plan::Dict{Int,Vector{Intervention}}...)
    @assert length(unique(typeof(first(first(values(p)))) for p in plan)) == length(plan) "Cannot parse more than one plan per intervention."
    merge(vcat, plan...)
end

# This method generates a Dict{Integer, Vector{Intervention}} even though the value is
# always singular. The resultant `Dict` is not expected to be used as-is, but rather
# merged with other interventions to create a master plan.
"""
    plan(Angling) # Assume always on
    plan(Angling; rate = 2.5e-3) # Always on with custom rate
    plan(Angling, 7; rate = 3.2e-3) # Only one year (custom rate)
    plan(Angling, 3:5) # Only years 3 to 5
    plan(Angling, [(period = 1:4, ),
                   (year = 5, rate = 7.2e-3),
                   (period = 7:9, )]) # Active in years 1-5, 7-9 with a custom rate
                                      # in year 5

Helper that provides complex scheduling for interventions with a simple interface.

The return type is `Dict{Int, Vector{Intervention}}`, were the key is each year
the collection of interventions will be active. As a convention, year `-1` denotes an
'always active' intervention.

The result can be provided to `municipality.interventions`, although
this function should almost always used in conjuction with [`planner`](@ref).
"""
plan(::Type{I}; kwargs...) where {I<:Intervention} = plan(I, -1; kwargs...)

function plan(::Type{I}, year::Int; kwargs...) where {I<:Intervention}
    schedule = Dict{Int,Vector{Intervention}}()
    schedule[year] = [I(; kwargs...)]
    schedule
end

function plan(::Type{I}, period::UnitRange{Int}; kwargs...) where {I<:Intervention}
    schedule = Dict{Int,Vector{Intervention}}()
    for year in period
        schedule[year] = [I(; kwargs...)]
    end
    schedule
end

function plan(::Type{I}, values::Vector{<:NamedTuple}) where {I<:Intervention}
    @assert all(haskey(v, :year) || haskey(v, :period) for v in values) "Each entry must contain a `year` or `period`."
    schedule = Dict{Int,Vector{Intervention}}()
    filter = (year = 5, period = 1:7) # Dummy tuple which we can use to dump our temporal data
    for entry in values
        params = Base.structdiff(entry, filter)
        if haskey(entry, :year)
            schedule[entry.year] = [I(; params...)]
        else
            for year in entry.period
                schedule[year] = [I(; params...)]
            end
        end
    end
    schedule
end

## Helpers

"""
    type2dict(struct; prefix = "")

Converts a `struct` into a `Dict`. Borrowed from DrWatson, but extended to allow some
prefix to be attached. This is helpful when merging multiple structs into one `Dict`.
"""
function type2dict(dt; prefix = "")
    di = Dict{Symbol,Any}()
    for n in propertynames(dt)
        id = isempty(prefix) ? n : Symbol(prefix, "_", n)
        di[id] = getproperty(dt, n)
    end
    di
end

