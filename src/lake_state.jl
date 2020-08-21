export sewage_water, vegetation

# A couple of different vegetation extractors, depending on the shape of your data
# Good for `model.lake`
function vegetation(
    lake::OrdinaryDiffEq.ODEIntegrator{A,B,C,D,E,<:LakeParameters{Scheffer}},
) where {A,B,C,D,E}
    bream = lake.sol.u[1, :]
    @. lake.p.K * (lake.p.H₃^2 / (lake.p.H₃^2 + bream^2))
end

# Good for a singular bream vector
function vegetation(B::Vector{Float64}, p::LakeParameters{Scheffer})
    @. p.K * (p.H₃^2 / (p.H₃^2 + B^2))
end

function lake_dynamics!(du, u, p::LakeParameters{Scheffer}, t)
    #TODO: New intervention dynamics not considered for Scheffer model
    B, P = u # g⋅m⁻² bream/pike density

    V = p.K * (p.H₃^2 / (p.H₃^2 + B^2)) # % of lake covered vetetation
    FR = B^2 / (B^2 + p.H₄^2) # fuctional response of pike

    du[1] =
        dB =
            p.ib + p.r * (p.nutrients / (p.nutrients + p.H₁)) * B - p.cb * B^2 -
            p.prmax * FR * P
    du[2] = dP = p.ip + p.ce * p.prmax * FR * P * (V / (V + p.H₂)) - p.mp * P - p.cp * P^2
end

function lake_dynamics!(du, u, p::LakeParameters{Martin}, t)
    B, P, V = u # g⋅m⁻² bream/pike/vegetation density

    FR = B^2 / (B^2 + p.H₄^2) # fuctional response of pike
    # Wrapped Cauchy distribution, simplifed to a yearly growth cycle between
    # March & July.
    # Expanded: γ*(1-ρ^2)/(1+ρ^2-2ρ*cos(2π*(t-μ)/τ))
    # TODO: Having some issues with this.
    #plant = p.pv > 0.0 ? -p.pv / (p.pv + 19.4872 * cos(2π / 365.0 * (t - 122.0))) : 0.0


    du[1] =
        dB =
            p.ib + p.r * (p.nutrients / (p.nutrients + p.H₁)) * B - p.tb * B - p.cb * B^2 -
            p.prmax * FR * P
    du[2] = dP = p.ip + p.ce * p.prmax * FR * P * (V / (V + p.H₂)) - p.mp * P - p.cp * P^2
    du[3] = dV = p.rv * V + p.pv * V - p.cv * V^2 - p.mv * (V * B^2 / (p.H₃^2 + B^2))
end

function sewage_water(m::ABM)
    !(m.nutrient_series isa Dynamic) && return 0.0
    if m.lake.p.nutrients >= m.init_nutrients
        nutrients_from_sewage = 0.0
        for municipality in municipalities(m)
            # Cheaper to count than length(collect()) here, but cannot do it implicitly with the union.
            # TODO: consider adding a household count to municipality.
            b =
                m.max_sewage_water / (
                    count(_ -> true, households(municipality, m)) -
                    municipality.tolerance_level_affectors
                )
            a = -b * municipality.tolerance_level_affectors
            nutrients_from_sewage += a + b * municipality.affectors
        end
        if m.lake.p.nutrients + nutrients_from_sewage < m.init_nutrients
            # In this case sewage recycling drops the nutrient level below initial
            m.init_nutrients - m.lake.p.nutrients
        else
            nutrients_from_sewage
        end
    else
        0.0
    end
end

