export Martin

struct Martin <: LakeModel end

@with_kw_noshow mutable struct MartinParameters <: LakeParameters
    @deftype Float64
    nutrients = 0.7 # current nutrient level
    ib = 2e-5 # g⋅m⁻²⋅day⁻¹ immigration rate of bream (9e-3 g⋅m⁻²⋅year⁻¹)
    ip = 2e-5 # g⋅m⁻²⋅day⁻¹ immigration rate of pike (9e-3 g⋅m⁻²⋅year⁻¹)
    r = 7.5e-3 # day⁻¹ maximum growth rate of bream (2.74 year⁻¹)
    H₁ = 0.5 # half saturation constant
    H₂ = 11 # % half saturation constant
    H₃ = 20 # g⋅m⁻² half saturation constant
    H₄ = 15 # g⋅m⁻² half saturation constant
    cb = 7.5e-5 # m⁻²⋅g⁻¹⋅day⁻¹ intraspecific competition constant for bream (0.0274 m⁻²⋅g⁻¹⋅year⁻¹)
    cp = 2.75e-4 # m⁻²⋅g⁻¹⋅day⁻¹ intraspecific competition constant for pike (0.1 m⁻²⋅g⁻¹⋅year⁻¹)
    prmax = 5e-2 # day⁻¹ maximum predation rate of pike (18.25 year⁻¹)
    ce = 0.1 # pike food conversion efficiency to growth
    mp = 2.25e-3 # day⁻¹ mortality rate of pike (0.82 year⁻¹)
    rv = 7e-3 # day⁻¹ vetegation growth rate
    cv = 6e-5 # m² intraspecific competition for vetetation
    mv = 7e-3 # day⁻¹ mortality of vegetation
    pv = 0.0 # day planting rate
    tb = 0.0 # day trawling rate
end

function lake_dynamics!(du, u, p::MartinParameters, t)
    B, P, V = u # g⋅m⁻² bream/pike/vegetation density

    FR = B^2 / (B^2 + p.H₄^2) # fuctional response of pike
    # Wrapped Cauchy distribution, simplifed to a yearly growth cycle between
    # March & July.
    # Expanded: γ*(1-ρ^2)/(1+ρ^2-2ρ*cos(2π*(t-μ)/τ))
    # NOTE: Having some issues with this, it's probably not necessary at all anyway.
    #plant = p.pv > 0.0 ? -p.pv / (p.pv + 19.4872 * cos(2π / 365.0 * (t - 122.0))) : 0.0

    du[1] =
        dB =
            p.ib + p.r * (p.nutrients / (p.nutrients + p.H₁)) * B - p.tb * B - p.cb * B^2 -
            p.prmax * FR * P
    du[2] = dP = p.ip + p.ce * p.prmax * FR * P * (V / (V + p.H₂)) - p.mp * P - p.cp * P^2
    du[3] = dV = p.rv * V + p.pv * V - p.cv * V^2 - p.mv * (V * B^2 / (p.H₃^2 + B^2))
end

function lake_initial_state(
    nutrients::Float64,
    bream::Float64,
    pike::Float64,
    vegetation::Float64,
    ::Type{Martin};
    kwargs...,
)
    ([bream, pike, vegetation], MartinParameters(; nutrients = nutrients, kwargs...))
end

LakeParameters(::Type{Martin}, nutr; kwargs...) =
    MartinParameters(; nutrients = nutr, kwargs...)

preset_conditions(::Type{Clear}, ::Type{Martin}) = (0.7, [20.5172, 1.7865, 56.8443])
preset_conditions(::Type{Turbid}, ::Type{Martin}) = (2.5, [83.0128, 0.0414705, 6.40048])
preset_conditions(::Type{X1}, ::Type{Martin}) = (2.2, [36.730, 2.87725, 26.6798]) #deep unstable
preset_conditions(::Type{X2}, ::Type{Martin}) = (1.05, [59.0606, 0.819124, 12.0023]) #unstable
preset_conditions(::Type{X3}, ::Type{Martin}) = (1.05, [64.0559, 0.374008, 10.3631]) #stable

preset_conditions(::Type{S1}, ::Type{Martin}) = (2.0, [79.597, 0.050, 6.928]) #turbid transition, stable
preset_conditions(::Type{S2}, ::Type{Martin}) = (3.5, [85.436, 0.0373, 6.061]) #turbid eutrophic, stable
preset_conditions(::Type{S3}, ::Type{Martin}) = (3.5, [20.0, 3.5, 50.0]) #clear eutrophic, unstable
preset_conditions(::Type{T1}, ::Type{Martin}) = (0.9, [21.647, 2.050, 53.726]) #clear oligotrophic, high pike concentration, stable
preset_conditions(::Type{T2}, ::Type{Martin}) = (2.0, [26.901, 2.809, 41.530]) #clear transition, stable
preset_conditions(::Type{T3}, ::Type{Martin}) = (3.5, [20.0, 3.5, 50.0]) #clear eutrophic unstable

function Base.show(io::IO, ::MIME"text/plain", p::MartinParameters)
    println(io, "Parameters for lake dynamics (Martin) model):")
    println(io, "Nutrient level: $(p.nutrients)")
    println(io, "Immigration rate (g⋅m⁻²⋅day⁻¹) for bream: $(p.ib), pike: $(p.ip)")
    println(
        io,
        "Growth rate (day⁻¹) for bream: $(p.r), Predation rate (day⁻¹) of pike: $(p.prmax)",
    )
    println(
        io,
        "Half sturation constants: H₁ $(p.H₁), H₂ $(p.H₂)%, H₃ $(p.H₃) g⋅m⁻², H₄ $(p.H₄) g⋅m⁻²",
    )
    println(
        io,
        "Intraspecific competition constant (g⋅m⁻²⋅day⁻¹) for bream: $(p.cb), pike: $(p.cp)",
    )
    println(
        io,
        "Pike food conversion efficiency to growth: $(p.ce), Mortalitiy rate (day⁻¹): $(p.mp)",
    )
    println(
        io,
        "Vegetation rates. Growth: $(p.rv) day⁻¹, mortality: $(p.mv) day⁻¹, competition: $(p.cv) m²",
    )
end

