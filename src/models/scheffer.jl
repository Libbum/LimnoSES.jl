struct Scheffer <: LakeModel end

@with_kw_noshow mutable struct SchefferParameters <: LakeParameters
    @deftype Float64
    nutrients = 0.7 # current nutrient level
    ib = 2e-5 # g⋅m⁻²⋅day⁻¹ immigration rate of bream (9e-3 g⋅m⁻²⋅year⁻¹)
    ip = 2e-5 # g⋅m⁻²⋅day⁻¹ immigration rate of pike (9e-3 g⋅m⁻²⋅year⁻¹)
    r = 7.5e-3 # day⁻¹ maximum growth rate of bream (2.74 year⁻¹)
    H₁ = 0.5 # half saturation constant
    H₂ = 10 # % half saturation constant
    H₃ = 20 # g⋅m⁻² half saturation constant
    H₄ = 15 # g⋅m⁻² half saturation constant
    cb = 7.5e-5 # m⁻²⋅g⁻¹⋅day⁻¹ intraspecific competition constant for bream (0.0274 m⁻²⋅g⁻¹⋅year⁻¹)
    cp = 2.75e-4 # m⁻²⋅g⁻¹⋅day⁻¹ intraspecific competition constant for pike (0.1 m⁻²⋅g⁻¹⋅year⁻¹)
    prmax = 5e-2 # day⁻¹ maximum predation rate of pike (18.25 year⁻¹)
    ce = 0.1 # pike food conversion efficiency to growth
    mp = 2.25e-3 # day⁻¹ mortality rate of pike (0.82 year⁻¹)
    K = 100 # % maximum vegetation coverage
end

function lake_dynamics!(du, u, p::SchefferParameters, t)
    #TODO: New intervention dynamics not considered for Scheffer model
    B, P = u # g⋅m⁻² bream/pike density

    V = p.K * (p.H₃^2 / (p.H₃^2 + B^2)) # % of lake covered vegetation
    FR = B^2 / (B^2 + p.H₄^2) # fuctional response of pike

    du[1] =
        dB =
            p.ib + p.r * (p.nutrients / (p.nutrients + p.H₁)) * B - p.cb * B^2 -
            p.prmax * FR * P
    du[2] = dP = p.ip + p.ce * p.prmax * FR * P * (V / (V + p.H₂)) - p.mp * P - p.cp * P^2
end

function lake_initial_state(
    nutrients::Float64,
    bream::Float64,
    pike::Float64,
    ::Type{Scheffer};
    kwargs...,
)
    ([bream, pike], SchefferParameters(; nutrients = nutrients, kwargs...))
end

LakeParameters(::Type{Scheffer}, nutr; kwargs...) = SchefferParameters(; nutrients = nutr, kwargs...)

preset_conditions(::Type{Clear}, ::Type{Scheffer}) = (0.7, [20.0, 1.8])
preset_conditions(::Type{Turbid}, ::Type{Scheffer}) = (2.5, [84.0, 0.04])

function Base.show(io::IO, ::MIME"text/plain", p::SchefferParameters)
    println(io, "Parameters for lake dynamics (Scheffer) model):")
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
    println(io, "Maximum vegetation coverage: $(p.K)%")
end
