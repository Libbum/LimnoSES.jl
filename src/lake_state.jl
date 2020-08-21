export sewage_water

function sewage_water(m::ABM)
    !(m.nutrient_series isa Dynamic) && return 0.0
    if m.lake.p.nutrients >= m.init_nutrients
        nutrients_from_sewage = 0.0
        for municipality in municipalities(m)
            b =
                m.max_sewage_water /
                (municipality.households - municipality.tolerance_level_affectors)
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


