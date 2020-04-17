export initialise

function initialise(;
    numagents = 100,
    griddims = (25, 25),
    experiment = Experiment(),
    municipality = Municipality(),
    lake_state = ClearLake,
    lake_parameters = LakeParameters(),
)

    if experiment.identifier != "none"
        if experiment.identifier == "transient-hysteresis"
            lake_state = ClearLake
            #NOTE: renaming as above will allow us to return this struct to immutable
            experiment.nutrient_series = Constant()
        elseif experiment.identifier == "transient-hysteresis-down"
            lake_state = TurbidLake
            experiment.nutrient_series = Constant()
        elseif experiment.identifier == "biggs-baseline"
            lake_state = ClearLake
            experiment.nutrient_series = Constant()
        elseif experiment.identifier == "speed-to-tip"
            experiment.target_nutrients = 2.5
        end
    end

    space = GridSpace(griddims, moore = true)
    properties = type2dict(experiment)
    push!(
        properties,
        :municipality => municipality,
        :lake => lake_state,
        :lake_parameters => lake_parameters,
        :tick => 0,
        :year => 0,
        :affectors => 0,
        :outcomes => Outcomes(),
        :init_nutrients => lake_state.nutrients,
        :transient_nutrients => lake_state.nutrients,
    ) #TODO: Why do we need this third nutrient counter?
    model = ABM(Household, space; properties = properties, scheduler = random_activation)
    for n in 1:numagents
        compliance = experiment.agents_uniform ? rand() : experiment.willingness_to_upgrade #NOTE: NetLogo implementation has a uniform houseowner type. Seems to be redundant, but if not, there needs to be an additional check here.
        agent = Household(n, (1, 1), compliance, false, rand(Bool), 0)
        add_agent_single!(agent, model)
    end
    return model
end
