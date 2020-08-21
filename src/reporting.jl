export upgrade_efficiency

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
