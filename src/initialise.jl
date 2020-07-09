export initialise

function initialise(;
    griddims = (25, 25),
    experiment = Experiment(),
    municipalities = Dict("main" => (Governance(), 100)),
    lake_state = lake_initial_state(Clear),
    lake_parameters = LakeParameters(Martin, first(lake_state)),
)
    @assert prod(griddims) >=
            sum(last(v) for v in values(municipalities)) + length(municipalities) "Total agents (municipalities + households) cannot be greater than the grid size"
    lake_state = last(lake_state) # Drop nutrient value from state (it's now in parameters)
    if experiment.identifier != "none"
        if experiment.identifier == "transient-hysteresis"
            nutr, lake_state = lake_initial_state(Clear)
            lake_parameters.nutrients = nutr
            experiment.nutrient_series = Constant()
        elseif experiment.identifier == "transient-hysteresis-down"
            nutr, lake_state = lake_initial_state(Turbid)
            lake_parameters.nutrients = nutr
            experiment.nutrient_series = Constant()
        elseif experiment.identifier == "biggs-baseline"
            nutr, lake_state = lake_initial_state(Clear)
            lake_parameters.nutrients = nutr
            experiment.nutrient_series = Constant()
        elseif experiment.identifier == "speed-to-tip"
            experiment.target_nutrients = 2.5
        end
    end

    #TODO: This needs to be nicer. Not sure of the best way to extend _state and _parameters at the same time here.
    if lake_parameters isa LakeParameters{Scheffer}
        lake_parameters = lake_parameters[2:3] #TODO: Check this. We moved away from SVectors since we want to make things mutable
    end

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
        juristiction_x = Int(round(first(griddims) * (houses / total_houses))) # Separation of municipalities in x
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

function type2dict(dt; prefix = "")
    di = Dict{Symbol,Any}()
    for n in propertynames(dt)
        id = isempty(prefix) ? n : Symbol(prefix, "_", n)
        di[id] = getproperty(dt, n)
    end
    di
end

