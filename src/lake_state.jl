# fuctional response of pike
bream_predation(B::Float64, H₄::Float64) = B^2 / (B^2 + H₄^2)

function dB(state::LakeState, p::LakeParameters{<:LakeModel})
    FR = bream_predation(state.bream, p.H₄)

    p.ib + p.r * (state.nutrients / (state.nutrients + p.H₁)) * state.bream -
    p.cb * state.bream^2 - p.prmax * FR * state.pike
end

function dP(state::LakeState, p::LakeParameters{<:LakeModel})
    FR = bream_predation(state.bream, p.H₄)

    p.ip +
    p.ce * p.prmax * state.pike * FR * (state.vegetation / (state.vegetation + p.H₂)) -
    p.mp * state.pike - p.cp * state.pike^2
end

function vegetation!(state::LakeState, p::LakeParameters{Scheffer})
    state.vegetation = p.K * (p.H₃^2 / (p.H₃^2 + state.bream^2))
end

function vegetation!(state::LakeState, p::LakeParameters{Martin})
    state.vegetation += (
        p.rv * state.vegetation - p.cv * state.vegetation^2 -
        p.mv * (state.vegetation * state.bream^2 / (p.H₃^2 + state.bream^2))
    )
end

function update_lake!(model::ABM{Household})
    model.lake.nutrients += dNutr(model)
    model.lake.bream += dB(model.lake, model.lake_parameters)
    vegetation!(model.lake, model.lake_parameters)
    model.lake.pike += dP(model.lake, model.lake_parameters)
end

