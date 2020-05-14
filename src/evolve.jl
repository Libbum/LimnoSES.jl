export agent_step!, model_step!

function agent_step!(agent, model) # Daily
    if model.tick % 365 == 0
        # Once a year households may update their oss
        if !agent.oss && agent.information
            #Agent has an understanding of compliance but has not yet upgraded.
            if rand() < agent.compliance
                agent.oss = true
                if model.houseowner_type isa Social
                    # Tell neighbours to increase their compliance
                    neighbors = space_neighbors(agent, model, model.neighbor_distance)
                    for nid in neighbors
                        model[nid].compliance = min(model[nid].compliance * 1.5, 0.99)
                    end
                end
            else
                agent.implementation_lag += 1
            end
        end
    end
    return
end

function model_step!(model)
    model.tick += 1
    if model.tick % 365 == 0
        model.year += 1
        # Update pollution level: nutrient inflow by affectors
        model.affectors = count(a -> !a.oss, allagents(model)) #####
        # checking the success of upgrade
        if model.outcomes.year_when_informed > 0 &&
           model.outcomes.year_of_full_upgrade <= model.year
            model.outcomes.upgraded_households_sum += count(a -> a.oss, allagents(model)) #NOTE: This is some cumulative trickery in Netlogo, and is not a true count of upgraded households.
        end
        #TODO: Logs

        # Nutrients affect lake dynamics
        update_settings!(model)
        update_nutrients!(model)
    end
    # Update bream stock, pike stock, vegetation and nutrients (daily)
    update_lake!(model)

    if model.outcomes.year_when_nutrients_became_critical == 0 &&
       model.lake.nutrients > model.critical_nutrients
        model.outcomes.year_when_nutrients_became_critical = model.year
    end

    # Municipality decides on sewage treatment rule
    if model.tick % 365 == 0 && model.regulate #TODO: we may be able to put this above before the daily block?
        # Check whether update of rules is needed.
        # When information from monitoring indicates need to act/rule, the legislation status is updated
        #NOTE: NetLogo implementation has Municipalities as an agent type, but only ever uses one of them. We have implemented this section with the assumption that there is only one ever.
        if model.municipality.information && !model.municipality.legislation
            model.municipality.legislation = true
            model.outcomes.year_when_informed = model.year - 1 # Netlogo comment: remember this as t1 for later calculation of implementation efficiency
        end

        # Monitoring (in this order to prevent immediate action based on new monitoring data)
        # NOTE: Could be incorperated into the above if clause, but kept separate since I suspect we'll be adding multiple municipalities in the near future.
        if !model.municipality.information
            if threshold_monitor(model)
                model.municipality.information = true
                if model.agents_uniform
                    # Immediate legislation when lake state is found to be undesirable
                    model.municipality.legislation = true
                    model.outcomes.year_when_informed = model.year
                end #Otherwise, it takes a year to act.
            end
        end

        for intervention in model.municipality.interventions
            regulate!(model, intervention)
        end

        # remember the year when the desired state is restored
        # look only for this year after degredadion and regulation of system has started
        if model.municipality.legislation && model.outcomes.year_when_desired_pike_is_back == 0
            restoration_log!(model)
        end
    end
    #TODO: Logs
    #TODO: Profier? Probably not needed.
end

function threshold_monitor(model::ABM{Household}; t::Pike=model.threshold_variable)
    trigger = model.respond_direct ? 0 : rand()
    trigger < pike_loss_perception!(model) #TODO: I don't like that this is mutating.
end

function threshold_monitor(model::ABM{Household}; t::Nutrients=model.threshold_variable)
    model.lake.nutrients > model.critical_nutrients
end

function restoration_log!(model::ABM{Household}; t::Pike=model.threshold_variable)
    if model.lake.pike > model.pike_expectation
        model.outcomes.year_when_desired_pike_is_back = model.year
    end
end

function restoration_log!(model::ABM{Household}; t::Nutrients=model.threshold_variable)
    if model.lake.nutrients < model.critical_nutrients
        model.outcomes.year_when_desired_level_is_back = model.year
    end
end

function regulate!(model::ABM{Household}, intervention::Planting)
    if model.lake.vegetation < 60
        #Up to 5% planting of vegetation per year
        model.lake.vegetation += model.lake.vegetation*0.05*rand()
    end
end

function regulate!(model::ABM{Household}, intervention::WastewaterTreatment)
    #Inform households, eventually enforcing.
    #TODO: This is a transcription of Netlogo and is pretty abysmal. Need to clean it up and perhaps move it to the agents section.
    if model.municipality.legislation && model.affectors > 0 ######
        if count(a -> a.oss, allagents(model)) == 0 ######
            for agent in
                Iterators.filter(a -> !a.oss && !a.information, allagents(model)) ######
                agent.information = true
                agent.implementation_lag = 0
            end
        end
        # Enforcement after 5 years
        if model.houseowner_type isa Enforced
            for agent in
                Iterators.filter(a -> a.implementation_lag > 4, allagents(model)) #####
                agent.compliance = min(agent.compliance * 1.5, 0.99)
            end
        end
    end
    # remember the year when all households were upgraded
    if all(a -> a.oss, allagents(model)) && model.outcomes.year_of_full_upgrade == 0 #####
        model.outcomes.year_of_full_upgrade = model.year
    end
end

function regulate!(model::ABM{Household}, intervention::Angling)
    # 10% higher mortality rate of pike (TODO: Hardcoded from default)
    model.lake_parameters.mp = 2.025e-3 # day⁻¹ mortality rate of pike (0.82 year⁻¹)
end

function regulate!(model::ABM{Household}, intervention::Trawling)
    if model.lake.bream > 14.0
        # up to 25% reduction in bream population via trawling per year
        model.lake.bream -= model.lake.bream*0.25*rand()
    end
end
