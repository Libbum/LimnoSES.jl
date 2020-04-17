export sewage_water, upgrade_efficiency, pike_loss_perception

function sewage_water(m::ABM{Household})
    if m.nutrient_series != Dynamic()
        return 0.0
    end
    #NOTE: a m.tick%365 == 0 check was here, but considering this is only called from dNutr which is only called from a yearly block, it was redundant.
    if m.lake.nutrients >= m.init_nutrients
        b = m.max_sewage_water / (nagents(m) - m.tolerance_level_affectors)
        a = -b * m.tolerance_level_affectors
        nutrients_from_sewage = a + b * m.affectors
        if m.lake.nutrients + nutrients_from_sewage < m.init_nutrients
            # In this case sewage recycling drops the nutrient level below initial
            m.init_nutrients - m.lake.nutrients
        else
            nutrients_from_sewage
        end
    else
        0.0
    end
end

function upgrade_efficiency(m::ABM{Household})
    if m.outcomes.year_when_informed > 0 && m.year > m.outcomes.year_when_informed
        if m.outcomes.year_of_full_upgrade > 0 && m.outcomes.year_of_full_upgrade < m.year
            100.0
        else
            t1 = m.outcomes.year_when_informed
            t2 = m.outcomes.year_of_full_upgrade > 0 ? m.outcomes.year_of_full_upgrade :
                m.year
            # Calculate current efficiency (with optimal efficiency in denominator)
            (m.outcomes.upgraded_households_sum * 100.0) / ((t2 - t1) * nagents(m))
        end
    else
        0.0
    end
end

function pike_loss_perception(m::ABM{Household})
    loss = m.pike_expectation - m.lake.pike
    if loss > 0
        loss^2 / (loss^2 + 0.75^2) #TODO: This is the partial defiancy of pike loss, look it up, seems pretty arbitrary currently.
    else
        0.0
    end
end


