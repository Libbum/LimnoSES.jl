export agent_step!, model_step!, households, municipalities

households(model::ABM) = Iterators.filter(a -> isa(a, Household), allagents(model))
households(municipality::Municipality, model::ABM) = Iterators.filter(
    a -> isa(a, Household) && a.municipality == municipality.id,
    allagents(model),
)
municipalities(model::ABM) = Iterators.filter(a -> isa(a, Municipality), allagents(model))

"""
    active_interventions(municipality, year)

Returns all active interventions in the planner. Due to the `year = -1` -> always active
convention we must merge the current year's plan with the `-1` key (if extant).
"""
active_interventions(m::Municipality, year::Int) = vcat(
    get(m.interventions, -1, Intervention[]),
    get(m.interventions, year, Intervention[]),
)

function agent_step!(house::Household, model) # yearly
    # Once a year households may update their oss
    if !house.oss && house.information
        #Agent has an understanding of compliance but has not yet upgraded.
        if rand(model.rng) < house.compliance
            house.oss = true
            municipality = model[house.municipality]
            if municipality.houseowner_type isa Social
                # Tell neighbours to increase their compliance
                neighbors = nearby_ids(house, model, municipality.neighbor_distance)
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

        #TODO: This check now essentially supersedes `municipality.regulate`
        any(
            i -> i isa WastewaterTreatment,
            active_interventions(municipality, model.year),
        ) && water_treatment!(model, municipality)
    end
end

function model_step!(model)
    # Run the decision optimiser only if this is not a test model.
    # This check avoids an recursion based stack overflow.
    haskey(model.properties, :test) || set_policy!(model)

    household_log!(model)
    # Update bream stock, pike stock, vegetation and nutrients (daily)
    OrdinaryDiffEq.step!(model.lake, 365.0, true)
    # Nutrients affect lake dynamics
    nutrient_load!(model, model.nutrient_series)
    OrdinaryDiffEq.u_modified!(model.lake, true)

    # Intervention which necessitate lake-wide changes
    aggregate_regulate!(model)
    model.year += 1

    # Monitoring (in this order to prevent immediate action based on new monitoring data)
    monitor!(model)

    # remember the year when the desired state is restored
    # look only for this year after degradation and regulation of system has started
    #TODO: This makes no sense in the context of multiple municipalities
    # if any(m->m.legislation, municipalities(model)) &&
    #     model.outcomes_year_when_desired_pike_is_back == 0
    #     restoration_log!(model)
    # end
end

function set_policy!(model::ABM)
    apply_knowledge!(model)
    if model.policy.start == model.year || (
        model.year > model.policy.start &&
        mod(model.year - model.policy.start, model.policy.every) == 0
    )
        make_decision!(model)
    end
end

function apply_knowledge!(model::ABM)
    for knowledge in model.knowledge
        apply_knowledge!(model, knowledge)
    end
end

function apply_knowledge!(model, knowledge::VegetationImbalance)
    # We know that it's appropriate to plant in deep turbid states, but
    # also that bream flips before everything else. This causes a vegetation
    # imbalance that puts the lake into a dramatically high vegetation state
    # that cannot be recovered by the optimiser. In addition, planting is no
    # longer the cheapest or most efficient option in this case, so we swap
    # all planned Planting interventions to Trawling.

    knowledge.year_target_reached > 0 && return nothing

    #TODO: This assumes `VegetationImbalance` only applies to Turbid->Clear
    # which is not explicitly true.
    if clear_state_region(model, model.year)
        # We have reached an appropriate state, stop interventions
        knowledge.year_target_reached = model.year
        for municipality in municipalities(model)
            for plans in
                values(filter(i -> i.first >= model.year, municipality.interventions))
                for (idx, p) in enumerate(plans)
                    deleteat!(plans, idx)
                end
            end
        end
    else
        B, P, V = model.lake.u
        if B < knowledge.bream_density_flip
            for municipality in municipalities(model)
                for plans in
                    values(filter(i -> i.first >= model.year, municipality.interventions))
                    for (idx, p) in enumerate(plans)
                        if p isa Planting
                            replace = Trawling(p.rate, p.cost)
                            deleteat!(plans, idx)
                            push!(plans, replace)
                        end
                    end
                end
            end
        end
    end
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
        trigger = municipality.respond_direct ? 0 : rand(model.rng)
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
    # Wastewater is internal to the municipality and therefore does not need to update rates here.
    schedule = Iterators.flatten(
        active_interventions(m, model.year) for m in municipalities(model)
    )

    planting = Iterators.filter(i -> i isa Planting, schedule)
    model.lake.p.pv = 0.0
    for project in planting
        model.lake.p.pv += project.rate
    end

    trawling = Iterators.filter(i -> i isa Trawling, schedule)
    model.lake.p.tb = 0.0
    for project in trawling
        model.lake.p.tb += project.rate
    end

    angling = Iterators.filter(i -> i isa Angling, schedule)
    model.lake.p.mp = model.init_pike_mortality
    for project in angling
        model.lake.p.mp += project.rate
    end

    OrdinaryDiffEq.u_modified!(model.lake, true)
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

