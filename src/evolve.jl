export agent_step!, model_step!

function agent_step!(agent, model) # Daily
    if model.tick % 365 == 0
        # Once a year households may update their oss
        if !agent.oss && agent.information
            #Agent has an understanding of compliance but has not yet upgraded.
            if rand() < agent.compliance
                agent.oss = true
                if model.houseowner_type == Social()
                    # Tell neighbours to increase their compliance
                    neighbor_cells = node_neighbors(agent, model) #TODO: 2nd and higher orders NN's dont seem to work. Additionally, for some reason you can only do this with the agent id rather than the agent itself.
                    for neighbor_cell in neighbor_cells
                        node_agents = get_node_agents(neighbor_cell, model)
                        # Skip iteration if the node is empty.
                        length(node_agents) == 0 && continue
                        for neighbour in node_agents
                            neighbour.compliance = min(neighbour.compliance * 1.5, 0.99)
                        end
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
           model.outcomes.upgraded_households_sum = nagents(model) - model.affectors ######
        end
        #TODO: Logs

        # Nutrients affect lake dynamics
        update_settings!(model)
        update_nutrients!(model)
    end
    # Update bream stock, pike stock and nutrients (daily)
    model.lake.bream += dB(model.lake, model.lake_parameters)
    model.lake.pike += dP(model.lake, model.lake_parameters)
    model.lake.nutrients += dNutr(model)

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
            threshold_monitored = if model.threshold_variable == Pike()
                trigger = model.respond_direct ? 0 : rand()
                trigger < pike_loss_perception!(model)
            elseif model.threshold_variable == Nutrients()
                model.lake.nutrients > model.critical_nutrients
            else
                #NOTE: This block only hits if we add a new Threshold type. Only here to mitigate undefined behaviour.
                false
            end
            if threshold_monitored
                model.municipality.information = true
                if model.agents_uniform #TODO: || houseowner_types != "none"
                    # Immediate legislation when lake state is found to be undesirable
                    model.municipality.legislation = true
                    model.outcomes.year_when_informed = model.year
                end #Otherwise, it takes a year to act.
            end
        end

        #Inform households, eventually enforcing.
        #TODO: This is a transcription of Netlogo and is pretty abysmal. Need to clean it up and perhaps move it to the agents section.
        if model.municipality.legislation && model.affectors > 0 ######
            if nagents(model) - model.affectors == 0 ######
                for agent in Iterators.filter(a -> !a.oss && !a.information, allagents(model)) ######
                    agent.information = true
                    agent.implementation_lag = 0
                end
            end
            # Enforcement after 5 years
            if model.houseowner_type == Enforced()
                for agent in Iterators.filter(a -> a.implementation_lag > 4, allagents(model)) #####
                    agent.compliance = min(agent.compliance * 1.5, 0.99)
                end
            end
        end

        # remember the year when all households were upgraded
        if all(a -> a.oss, allagents(model)) && model.outcomes.year_of_full_upgrade == 0 #####
            model.outcomes.year_of_full_upgrade = year
        end

        # remember the year when the desired state is restored
        # look only for this year after degredadion and regulation of system has started
        if model.municipality.legislation
            if model.threshold_variable == Pike() &&
               model.outcomes.year_when_desired_pike_is_back == 0 &&
               model.lake.pike > model.pike_expectation
                model.outcomes.year_when_desired_pike_is_back = model.year
            elseif model.threshold_variable == Nutrients() &&
                   model.outcomes.year_when_desired_level_is_back == 0 &&
                   model.lake.nutrients < model.critical_nutrients
                model.outcomes.year_when_desired_level_is_back = model.year
            end
        end
    end
    #TODO: Logs
    #TODO: Profier? Probably not needed.
end


