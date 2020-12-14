"""
    nutrient_load(model::ABM, series<:NutrientSeries)

Updates lake nutrient concentration accorting to `series` type.

See [NutrientSeries](@ref) for more details.
"""
nutrient_load!(m::ABM, series::Constant) = nothing

function nutrient_load!(m::ABM, series::Dynamic)
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
            m.lake.p.nutrients += m.init_nutrients - m.lake.p.nutrients
        else
            m.lake.p.nutrients += nutrients_from_sewage
        end
    end
end

function nutrient_load!(m::ABM, series::TransientUp)
    if m.year > series.start_year
        if round(m.lake.p.nutrients + m.nutrient_change; sigdigits = 2) >=
           m.target_nutrients
            m.lake.p.nutrients = m.target_nutrients
            if series.post_target_series isa TransientDown
                m.target_nutrients = m.init_nutrients
            end
            m.nutrient_series = series.post_target_series
        else
            m.lake.p.nutrients += m.nutrient_change
        end
    end
end

function nutrient_load!(m::ABM, series::TransientDown)
    if m.year > series.start_year
        if round(m.lake.p.nutrients - m.nutrient_change; sigdigits = 2) <=
           m.target_nutrients
            m.lake.p.nutrients = m.target_nutrients
            if series.post_target_series isa TransientUp
                m.target_nutrients = m.init_nutrients
            end
            m.nutrient_series = series.post_target_series
        else
            m.lake.p.nutrients -= m.nutrient_change
        end
    end
end

