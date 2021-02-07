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

function nutrient_load!(m::ABM, series::Noise)
    if !isempty(series.process.S₁.data) && m.nutrient_stabilise == m.year
        # Time to flip to stable
        # TODO: Generalise this
        # For now, the only time we need this is in a S2-T2 transition
        m.nutrient_series = Noise(WienerProcess(m.year,m.lake.p.nutrients), 1.0, 2.5)
        series = m.nutrient_series
    end
    step_noise!(series, 1)
    m.lake.p.nutrients = series.process.curW
end

function step_noise!(noise::Noise, dt)
    N = noise.process
    N.dt = dt
    while true
        setup_next_step!(N, nothing, nothing)
        if noise.min <= N.curW + N.dW <= noise.max
            accept_step!(N, dt, nothing, nothing, false)
            break
        else
            reject_step!(N, dt, nothing, nothing)
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

