export initialise

function initialise(;
    griddims = (25, 25),
    experiment = Experiment(),
    municipalities = Dict("main" => (Governance(), 100)),
    lake_setup = lake_initial_state(Clear, Martin),
)
    @assert prod(griddims) >=
            sum(last(v) for v in values(municipalities)) + length(municipalities) "Total agents (municipalities + households) cannot be greater than the grid size"

    lake_state, lake_parameters = lake_setup
    prob = ODEProblem(lake_dynamics!, lake_state, (0.0, Inf), lake_parameters)

    space = GridSpace(griddims, moore = true)
    properties = type2dict(experiment)
    merge!(properties, type2dict(Outcomes(); prefix = "outcomes"))
    push!(
        properties,
        :lake => init(prob, Tsit5()),
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

function type2dict(dt; prefix = "")
    di = Dict{Symbol,Any}()
    for n in propertynames(dt)
        id = isempty(prefix) ? n : Symbol(prefix, "_", n)
        di[id] = getproperty(dt, n)
    end
    di
end

