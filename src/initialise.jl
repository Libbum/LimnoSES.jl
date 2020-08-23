export initialise

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
    prob = OrdinaryDiffEq.ODEProblem(lake_dynamics!, lake_state, (0.0, Inf), lake_parameters)

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
        Union{Household,Municipality},
        space;
        properties = properties,
        scheduler = by_type((Household, Municipality), true),
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
            gov.regulate,
            gov.respond_direct,
            gov.threshold_variable,
            gov.interventions,
            gov.agents_uniform,
            gov.houseowner_type,
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
            house =
                Household(nextid(model), pos, compliance, false, false, 0, municipality_id)
            add_agent_pos!(house, model)
        end
        real_estate_x += juristiction_x
    end
    return model
end

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

"""
    vec_merge([dict1, dict2, dict3])

Merges multiple dictionaries where the `supertype` of each dictionary matches.
Result has the same keys, and a `Vector{<:SuperType}` as the values.
"""
function vec_merge(dicts::Array{Dict{A,B} where B,1}) where {A}
    @assert !isempty(dicts)
    base_type = supertype(typeof(dicts[1][1]))
    new_dict = Dict{A,Vector{base_type}}()
    for dict in dicts
        for (k, v) in pairs(dict)
            row = get(new_dict, k, base_type[])
            push!(row, v)
            new_dict[k] = row
        end
    end
    new_dict
end

