#NOTE: Looks like there's also constant-or-dynamic-nutrients and that separates out transient and non transient nutruient updates..
function dNutr(m::ABM{Household})
    #NOTE: This is the NetLogo implementation. Can we not just directly replace this with the `sewage_water` function? a*b+c - a*b => c
    #nutrients + local-sewage - local-losses
    #m.lake.nutrients +
    (m.recycling_rate * m.lake.nutrients + sewage_water(m)) -
    (m.recycling_rate * m.lake.nutrients)

    #sewage_water(m)
end

function pike_loss_perception!(m::ABM{Household})
    loss = m.pike_expectation - m.lake.pike
    perception = 0.0
    if loss > 0
        if m.outcomes.year_when_pike_became_critical == 0
            m.outcomes.year_when_pike_became_critical = m.year
        end
        perception = loss^2 / (loss^2 + 0.75^2) #TODO: This is the partial defiancy of pike loss, look it up, seems pretty arbitrary currently.
    end
    perception
end

#TODO: Netlogo logic here is a mess.
#NOTE: Netlogo incorporates a stopping function, we dont have that here, so it's not currently useful.
function update_settings!(m::ABM{Household})
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
                m.nutrient_series == TransientUp() &&
                round(m.lake.nutrients; sigdigits = 2) >= m.target_nutrients
            ) || (
                m.nutrient_series == TransientDown() &&
                round(m.lake.nutrients; sigdigits = 2) <= m.target_nutrients
            )
                if m.identifier == "biggs-baseline" && m.nutrient_series == TransientUp()
                    m.nutrient_series = TransientDown()
                    m.target_nutrients = m.init_nutrients
                else
                    m.nutrient_series = Constant()
                    #time-to-finish = 31
                    m.lake.nutrients = m.target_nutrients
                end
                #Phase 2: stable-state on final nutrient level, stop criterion
                #time-to-finish -= 1
            end
        end
    end
end

function update_nutrients!(m::ABM{Household})
    if m.nutrient_series == TransientUp()
        dn = m.lake.nutrients + m.nutrient_change
        m.lake.nutrients = dn > m.target_nutrients ? m.target_nutrients : dn
    elseif m.nutrient_series == TransientDown()
        dn = m.lake.nutrients - m.nutrient_change
        m.lake.nutrients = dn < m.target_nutrients ? m.target_nutrients : dn
    end
end

