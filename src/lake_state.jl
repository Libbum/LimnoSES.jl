export lake_vegetation

function dB(state::LakeState, p::LakeParameters)
    FR = bream_predation(state.bream, p.H₄)

    return p.ib + p.r * (state.nutrients / (state.nutrients + p.H₁)) * state.bream -
           p.cb * state.bream^2 - p.prmax * FR * state.pike
end

function dP(state::LakeState, p::LakeParameters)
    V = lake_vegetation(state.bream, p.K, p.H₃)
    FR = bream_predation(state.bream, p.H₄)

    return p.ip + p.ce * p.prmax * FR * state.pike * (V / (V + p.H₂)) - p.mp * state.pike -
           p.cp * state.pike^2
end

function lake_vegetation(B::Float64, K::Float64, H₃::Float64)
    K * (H₃^2 / (H₃^2 + B^2)) # % of lake covered vegetation
end

function bream_predation(B::Float64, H₄::Float64)
    # fuctional response of pike
    B^2 / (B^2 + H₄^2)
end


