export upgrade_efficiency, vegetation, nutrients

# Pre-defined helpers for data collection
nutrients(model) = model.lake.p.nutrients

# A couple of different vegetation extractors, depending on the shape of your data
# Good for `model.lake`
function vegetation(
    lake::OrdinaryDiffEq.ODEIntegrator{A,B,C,D,E,MartinParameters},
) where {A,B,C,D,E}
    bream = lake.sol.u[1, :]
    @. lake.p.K * (lake.p.H₃^2 / (lake.p.H₃^2 + bream^2))
end

# Good for a singular bream vector
function vegetation(B::Vector{Float64}, p::SchefferParameters)
    @. p.K * (p.H₃^2 / (p.H₃^2 + B^2))
end


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
