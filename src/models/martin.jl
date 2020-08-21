struct Martin <: LakeModel end

struct X1 <: LakeDefinition end
struct X2 <: LakeDefinition end
struct X3 <: LakeDefinition end

@with_kw_noshow mutable struct MartinParameters <: LakeParameters
    @deftype Float64
    nutrients = 0.7 # current nutrient level
    ib = 2e-5 # g⋅m⁻²⋅day⁻¹ immigration rate of bream (9e-3 g⋅m⁻²⋅year⁻¹)
    ip = 2e-5 # g⋅m⁻²⋅day⁻¹ immigration rate of pike (9e-3 g⋅m⁻²⋅year⁻¹)
    r = 7.5e-3 # day⁻¹ maximum growth rate of bream (2.74 year⁻¹)
    H₁ = 0.5 # half saturation constant
    H₂ = 20 # % half saturation constant
    H₃ = 20 # g⋅m⁻² half saturation constant
    H₄ = 15 # g⋅m⁻² half saturation constant
    cb = 7.5e-5 # m⁻²⋅g⁻¹⋅day⁻¹ intraspecific competition constant for bream (0.0274 m⁻²⋅g⁻¹⋅year⁻¹)
    cp = 2.75e-4 # m⁻²⋅g⁻¹⋅day⁻¹ intraspecific competition constant for pike (0.1 m⁻²⋅g⁻¹⋅year⁻¹)
    prmax = 5e-2 # day⁻¹ maximum predation rate of pike (18.25 year⁻¹)
    ce = 0.14 # pike food conversion efficiency to growth
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

preset_conditions(::Type{Clear}, ::Type{Martin}) = (0.7, [15.093, 1.947, 74.333])
preset_conditions(::Type{Turbid}, ::Type{Martin}) = (2.5, [83.085, 0.032, 6.390])
preset_conditions(::Type{X1}, ::Type{Martin}) = (2.2, [60.036, 0.738, 11.654])
preset_conditions(::Type{X2}, ::Type{Martin}) = (1.05, [60.036, 0.738, 11.654])
preset_conditions(::Type{X3}, ::Type{Martin}) = (1.05, [65.984, 0.183, 9.816])

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

