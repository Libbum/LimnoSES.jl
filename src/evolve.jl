export agent_step!, model_step!, households, municipalities

households(model::ABM) = Iterators.filter(a -> isa(a, Household), allagents(model))
households(municipality::Municipality, model::ABM) = Iterators.filter(
    a -> isa(a, Household) && a.municipality == municipality.id,
    allagents(model),
)
municipalities(model::ABM) = Iterators.filter(a -> isa(a, Municipality), allagents(model))

function agent_step!(house::Household, model) # yearly
    # Once a year households may update their oss
    if !house.oss && house.information
        #Agent has an understanding of compliance but has not yet upgraded.
        if rand() < house.compliance
            house.oss = true
            municipality = model[house.municipality]
            if municipality.houseowner_type isa Social
                # Tell neighbours to increase their compliance
                neighbors = space_neighbors(house, model, municipality.neighbor_distance)
                # We must filter out bordering municipalities first
                for nid in Iterators.filter(
                    n ->
                        model[n] isa Household &&
                        model[n].municipality == house.municipality,
                    neighbors,
                )
                    model[nid].compliance = min(model[nid].compliance * 1.5, 0.99)
                end
            end
        else
            house.implementation_lag += 1
        end
    end
end

function agent_step!(municipality::Municipality, model)
    # Update pollution level: nutrient inflow by affectors
    municipality.affectors = count(a -> !a.oss, households(municipality, model))
    # Municipality decides on sewage treatment rule
    if municipality.regulate
        # Check whether update of rules is needed.
        # When information from monitoring indicates need to act/rule, the legislation status is updated
        if municipality.information && !municipality.legislation
            municipality.legislation = true
            #TODO: Not useful in a multi municipality context
            #model.outcomes_year_when_informed = model.year - 1 # Netlogo comment: remember this as t1 for later calculation of implementation efficiency
        end

        water_treatment!(model, municipality)
    end
end

function model_step!(model)

    household_log!(model)
    # Update bream stock, pike stock, vegetation and nutrients (daily)
    OrdinaryDiffEq.step!(model.lake, 365.0, true)
    # Nutrients affect lake dynamics
    nutrient_load!(model, model.nutrient_series)
    OrdinaryDiffEq.u_modified!(model.lake, true)

    # Interventions which neccesitate lake-wide changes
    aggregate_regulate!(model)
    model.year += 1

    # Monitoring (in this order to prevent immediate action based on new monitoring data)
    monitor!(model)

    # remember the year when the desired state is restored
    # look only for this year after degredadion and regulation of system has started
    #TODO: This makes no sense in the context of multiple municipalities
    # if any(m->m.legislation, municipalities(model)) &&
    #     model.outcomes_year_when_desired_pike_is_back == 0
    #     restoration_log!(model)
    # end
end

function household_log!(model::ABM)
    # checking the success of upgrade
    if model.outcomes_year_when_informed > 0 &&
       model.outcomes_year_of_full_upgrade <= model.year
        model.outcomes_upgraded_households_sum += count(a -> a.oss, households(model)) #NOTE: This is some cumulative trickery in Netlogo, and is not a true count of upgraded households.
    end
    # remember the year when all households were upgraded
    if model.outcomes_year_of_full_upgrade == 0 && all(a -> a.oss, households(model))
        model.outcomes_year_of_full_upgrade = model.year
    end
end

function monitor!(model::ABM)
    loss = model.pike_expectation - model.lake.u[2] #pike
    if loss > 0 && model.outcomes_year_when_pike_became_critical == 0
        model.outcomes_year_when_pike_became_critical = model.year
    end
    if model.outcomes_year_when_nutrients_became_critical == 0 &&
       model.lake.p.nutrients > model.critical_nutrients
        model.outcomes_year_when_nutrients_became_critical = model.year
    end
    for municipality in municipalities(model)
        if !municipality.information && threshold_monitor(loss, municipality, model)
            municipality.information = true
            if municipality.agents_uniform
                # Immediate legislation when lake state is found to be undesirable
                municipality.legislation = true
                #TODO: Not useful in a multi municipality context
                #TODO: Should be brought into a municipality based governance strategy
                #model.outcomes_year_when_informed = model.year
            end #Otherwise, it takes a year to act.
        end
    end
end

function threshold_monitor(loss::Float64, municipality::Municipality, model::ABM)
    if municipality.threshold_variable isa Nutrients
        return model.lake.p.nutrients > model.critical_nutrients
    elseif municipality.threshold_variable isa Pike
        trigger = municipality.respond_direct ? 0 : rand()
        return trigger < pike_loss_perception(loss)
    end
    false
end

function pike_loss_perception(loss::Float64)
    #TODO: This is the partial defiancy of pike loss, look it up, seems pretty arbitrary currently.
    loss > 0 ? loss^2 / (loss^2 + 0.75^2) : 0
end

#TODO: This makes no sense in the context of multiple municipalities
#function restoration_log!(model::ABM)
#    if model.threshold_variable isa Nutrients
#        if model.lake.p.nutrients < model.critical_nutrients
#            model.outcomes_year_when_desired_level_is_back = model.year
#        end
#    elseif model.threshold_variable isa Pike
#        if model.lake.pike > model.pike_expectation
#            model.outcomes_year_when_desired_pike_is_back = model.year
#        end
#    end
#end

function aggregate_regulate!(model::ABM)
    # Wastewater is internal to the municipality and therefore does not need to update rates.
    # TODO: clean this up into a loop or macro
    new_rate = 0.0
    for planter in Iterators.filter(
        m -> m.regulate && any(x -> x isa Planting, m.interventions),
        municipalities(model),
    )
        rate, status = plant!(model, planter)
        if status isa Running
            new_rate += rate
        end
    end
    model.lake.p.pv = new_rate

    new_rate = 0.0
    for trawler in Iterators.filter(
        m -> m.regulate && any(x -> x isa Trawling, m.interventions),
        municipalities(model),
    )
        rate, status = trawling!(model, trawler)
        if status isa Running
            new_rate += rate
        end
    end
    model.lake.p.tb = new_rate

    new_rate = 0.0
    for angler in Iterators.filter(
        m -> m.regulate && any(x -> x isa Angling, m.interventions),
        municipalities(model),
    )
        rate, status = angling!(model, angler)
        if status isa Running
            new_rate += rate
        end
    end
    model.lake.p.mp = model.init_pike_mortality + new_rate
    OrdinaryDiffEq.u_modified!(model.lake, true)
end

function plant!(model::ABM, municipality::Municipality)
    # Currently assumes we can only do one intervention per run and is triggered via a threshold.
    idx = findfirst(p -> p isa Planting, municipality.interventions)
    intervention = municipality.interventions[idx]
    # Only interested in capturing the rate if the intervetion changes it
    rate = 0.0
    # u[3] is Vegetation
    if intervention.status isa Idle && model.lake.u[3] < intervention.threshold
        intervention.status = Running()
        # Planting will begin next year.
        intervention.year_when_planting_begins = model.year + 1
    end

    if intervention.status isa Running
        if intervention.years_active > intervention.campaign_length
            intervention.status = Complete()
        else
            bream_diff = isempty(intervention.yearly_stock_bream) ? 0.0 :
                (model.lake.u[1] / first(intervention.yearly_stock_bream[end]) - 1) * 100
            veg_diff = isempty(intervention.yearly_stock_vegetation) ? 0.0 :
                (model.lake.u[3] / first(intervention.yearly_stock_vegetation[end]) - 1) *
            100
            push!(intervention.yearly_stock_bream, (model.lake.u[1], bream_diff))
            push!(intervention.yearly_stock_vegetation, (model.lake.u[3], veg_diff))
            rate = intervention.rate
            intervention.years_active += 1
        end
    end
    (rate, intervention.status)
end

function trawling!(model::ABM, municipality::Municipality)
    # Currently assumes we can only do one intervention per run and is triggered via a threshold.
    rate = 0.0
    idx = findfirst(t -> t isa Trawling, municipality.interventions)
    intervention = municipality.interventions[idx]
    # u[1] is Bream
    if intervention.status isa Idle && model.lake.u[1] > intervention.threshold
        intervention.status = Running()
        # Trawling will begin next year.
        intervention.year_when_trawling_begins = model.year + 1
    end

    if intervention.status isa Running
        if intervention.years_active > intervention.campaign_length
            intervention.status = Complete()
        else
            bream_diff = isempty(intervention.yearly_stock_bream) ? 0.0 :
                (model.lake.u[1] / first(intervention.yearly_stock_bream[end]) - 1) * 100
            veg_diff = isempty(intervention.yearly_stock_vegetation) ? 0.0 :
                (model.lake.u[3] / first(intervention.yearly_stock_vegetation[end]) - 1) *
            100
            push!(intervention.yearly_stock_bream, (model.lake.u[1], bream_diff))
            push!(intervention.yearly_stock_vegetation, (model.lake.u[3], veg_diff))
            rate = intervention.rate
            intervention.years_active += 1
        end
    end
    (rate, intervention.status)
end

function angling!(model::ABM, municipality::Municipality)
    rate = 0.0
    idx = findfirst(a -> a isa Angling, municipality.interventions)
    intervention = municipality.interventions[idx]
    if intervention.status isa Idle
        # Angling is a long term intervention. We do not turn it off.
        intervention.status = Running()
        rate = intervention.rate
    elseif intervention.status isa Running
        rate = intervention.rate
    end
    (rate, intervention.status)
end

function water_treatment!(model::ABM, municipality::Municipality)
    #Inform households, eventually enforcing.
    if municipality.legislation && municipality.affectors > 0
        if count(a -> a.oss, households(municipality, model)) == 0
            #TODO: This assumes perfect information transfer, and only happens once.
            # Delays will happen here and we should structure this as an information campaign in the future
            for house in Iterators.filter(
                a -> !a.oss && !a.information,
                households(municipality, model),
            )
                house.information = true
                house.implementation_lag = 0
            end
        end
        # Enforcement after 5 years
        if municipality.houseowner_type isa Enforced
            for house in Iterators.filter(
                a -> a.implementation_lag > 4,
                households(municipality, model),
            )
                house.compliance = min(house.compliance * 1.5, 0.99)
            end
        end
    end
end

