export upgrade_efficiency #interface_collect!

function upgrade_efficiency(m::ABM)
    if m.year > m.outcomes_year_when_informed > 0
        if 0 < m.outcomes_year_of_full_upgrade < m.year
            100.0
        else
            t1 = m.outcomes_year_when_informed
            t2 = m.outcomes_year_of_full_upgrade > 0 ? m.outcomes_year_of_full_upgrade :
                m.year
            # Calculate current efficiency (with optimal efficiency in denominator)
            (m.outcomes_upgraded_households_sum * 100.0) / ((t2 - t1) * nagents(m))
        end
    else
        0.0
    end
end

#function interface_collect!(model::ABM)
#    # Daily model
#    bream(m) = m.lake.bream
#    pike(m) = m.lake.pike
#    vegetation(m) = m.lake.vegetation
#    mdata = [bream, pike, sewage_water, vegetation]
#    # Yearly model
#    nutrients(m) = m.lake.p.nutrients
#    yearly_mdata = [pike_loss_perception, upgrade_efficiency, nutrients, :affectors]
#    # Yearly Agent
#    adata = [:compliance]
#    # Yearly Aggregated Agent
#    agg_adata = [(:information, count), (:oss, count)]
#
#    # Initialise dataframes
#    model_df = init_model_dataframe(model, mdata)
#    yearly_model_df = init_model_dataframe(model, yearly_mdata)
#    agent_df = init_agent_dataframe(model, adata)
#    agg_agent_df = init_agent_dataframe(model, agg_adata)
#
#    # Store initial values
#    collect_model_data!(model_df, model, mdata, 0)
#    collect_model_data!(yearly_model_df, model, yearly_mdata, 0)
#    collect_agent_data!(agent_df, model, adata, 0)
#    collect_agent_data!(agg_agent_df, model, agg_adata, 0)
#
#    # Run simulation
#    for t in 1:simlength
#        Agents.step!(model, agent_step!, model_step!, 1)
#        collect_model_data!(model_df, model, mdata, t)
#        if t % 365 == 0
#            year = Int(t / 365)
#            collect_model_data!(yearly_model_df, model, yearly_mdata, year)
#            collect_agent_data!(agent_df, model, adata, year)
#            collect_agent_data!(agg_agent_df, model, agg_adata, year)
#        end
#    end
#
#    Interface.InterfaceData(model_df, innerjoin(yearly_model_df, agg_agent_df, on = :step), agent_df)
#end


