#TODO: Netlogo logic here is a mess.
#NOTE: Netlogo incorporates a stopping function, we dont have that here, so it's not currently useful.
function legacy_scenarios!(m::ABM)
    if m.identifier != "none"
        #Phase 1: transient, static increase of nutrients, different speeds, same interval
        if m.year == 11
            if m.identifier in ["transient-hysteresis", "speed-to-tip", "biggs-baseline"]
                m.nutrient_series = TransientUp()
            elseif m.identifier == "transient-hysteresis-down"
                m.nutrient_series = TransientDown()
            end
        elseif m.year > 11
            # check wether nutrient level has reached target
            if (
                m.nutrient_series isa TransientUp &&
                round(m.lake.p.nutrients; sigdigits = 2) >= m.target_nutrients
            ) || (
                m.nutrient_series isa TransientDown &&
                round(m.lake.p.nutrients; sigdigits = 2) <= m.target_nutrients
            )
                if m.identifier == "biggs-baseline" && m.nutrient_series isa TransientUp
                    m.nutrient_series = TransientDown()
                    m.target_nutrients = m.init_nutrients
                else
                    m.nutrient_series = Constant()
                    #time-to-finish = 31
                    m.lake.p.nutrients = m.target_nutrients
                end
                #Phase 2: stable-state on final nutrient level, stop criterion
                #time-to-finish -= 1
            end
        end
    end
    if m.nutrient_series isa TransientUp
        dn = m.lake.p.nutrients + m.nutrient_change
        m.lake.p.nutrients = dn > m.target_nutrients ? m.target_nutrients : dn
    elseif m.nutrient_series isa TransientDown
        dn = m.lake.p.nutrients - m.nutrient_change
        m.lake.p.nutrients = dn < m.target_nutrients ? m.target_nutrients : dn
    end
end


