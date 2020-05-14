using Printf

export Household,
    Introverted,
    Social,
    Enforced,
    Pike,
    Nutrients,
    Constant,
    Dynamic,
    TransientUp,
    TransientDown,
    Municipality,
    Planting,
    WastewaterTreatment,
    Trawling,
    Angling,
    LakeState,
    Clear,
    Turbid,
    X1,
    X2,
    X3,
    Experiment,
    LakeParameters,
    Martin,
    Scheffer

mutable struct Household <: AbstractAgent
    id::Int # The identifier number of the agent
    pos::Tuple{Int,Int} # The x, y location of the agent on a 2D grid
    compliance::Float64 # From willingness to upgrade
    oss::Bool # Is the sewage system upgraded or not?
    information::Bool # Has this agent been told about the upgrade?
    implementation_lag::Int # How long does it take the agent to choose to upgrade?
end

abstract type Threshold end

struct Pike <: Threshold end
struct Nutrients <: Threshold end

abstract type HouseOwner end

struct Introverted <: HouseOwner end
struct Social <: HouseOwner end
struct Enforced <: HouseOwner end

abstract type NutrientSeries end

struct Constant <: NutrientSeries end
struct Dynamic <: NutrientSeries end
struct TransientUp <: NutrientSeries end
struct TransientDown <: NutrientSeries end

# Properties of the experiment. For now this is a drop in for GUI values
@with_kw mutable struct Experiment
    identifier::String = "biggs-baseline" # String for the moment. Might want to reconsider this in the future.
    # Related to home owners
    agents_uniform::Bool = false
    houseowner_type::HouseOwner = Introverted()
    willingness_to_upgrade::Float64 = 0.2
    tolerance_level_affectors::Float64 = 50.0
    neighbor_distance::Int = 3
    # Related to municipality
    regulate::Bool = false
    respond_direct::Bool = true
    threshold_variable::Threshold = Nutrients()
    # Related to lake
    pike_expectation::Float64 = 1.4
    target_nutrients::Float64 = 0.7
    nutrient_series::NutrientSeries = Constant()
    nutrient_change::Float64 = 0.1
    critical_nutrients::Float64 = 3.0
    recycling_rate::Float64 = 0.1
    max_sewage_water::Float64 = 0.1
end

@with_kw_noshow mutable struct Outcomes
    @deftype Int
    year_when_informed = 0# remembers the first year when municipality was informed about critical lake status from monitoring
    year_when_pike_became_critical = 0 # remember the first year pike is below expectation level
    year_when_nutrients_became_critical = 0 # remember the first year nutrients are above expectation level
    year_when_desired_pike_is_back = 0
    year_when_desired_level_is_back = 0
    upgraded_households_sum = 0 # cumulatively aggregates the number of upgraded oss each year
    year_of_full_upgrade = 0 #remeber the year when all households finished their update
end

function Base.show(io::IO, ::MIME"text/plain", p::Outcomes)
    println(io, "Years when important events occur:")
    if p.year_when_informed != 0
        println(
            io,
            "Monitoring informs municipality of critical lake status: $(p.year_when_informed)",
        )
    end
    if p.year_when_pike_became_critical != 0
        println(io, "Pike population became critical: $(p.year_when_pike_became_critical)")
    end
    if p.year_when_nutrients_became_critical != 0
        println(
            io,
            "Nuturient level became critical: $(p.year_when_nutrients_became_critical)",
        )
    end
    if p.year_when_desired_pike_is_back != 0
        println(io, "Pike population recovered: $(p.year_when_desired_pike_is_back)")
    end
    if p.year_when_desired_level_is_back != 0
        println(io, "Nuturient level recovered: $(p.year_when_desired_level_is_back)")
    end
    if p.year_of_full_upgrade != 0
        println(io, "Households fully upgraded: $(p.year_of_full_upgrade)")
    else
        println(io, "Number of households upgraded: $(p.upgraded_households_sum)")
    end
end

abstract type Interventions end

struct Planting <: Interventions end
struct WastewaterTreatment <: Interventions end
struct Trawling <: Interventions end
struct Angling <: Interventions end

@with_kw_noshow mutable struct Municipality
    money::Float64 = 10.0 # money to spend on monitoring/rule enforcement
    information::Bool = false # information on state of the lake
    legislation::Bool = false # legislation power to enforce new rules
    interventions::Vector{Interventions} = [WastewaterTreatment()] # Set of interventions municipality will act on
end

# Lake dynamics
abstract type LakeModel end

struct Scheffer <: LakeModel end
struct Martin <: LakeModel end

# Nutrient range showing bistability in M0 [1,2.1]; M1 [0.7,1.5]
@with_kw_noshow mutable struct LakeParameters{M<:LakeModel}
    @deftype Float64
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
    K = 100 # % maximum vegetation coverage
    rv = 7e-3 # day⁻¹ vetegation growth rate
    cv = 6e-5 # m² intraspecific competition for vetetation
    mv = 7e-3 # day⁻¹ mortality of vegetation
end

LakeParameters(::Type{Scheffer}; kwargs...) =
    LakeParameters{Scheffer}(; H₂ = 10, ce = 0.1, rv = 0, cv = 0, mv = 0, kwargs...)
LakeParameters(::Type{Martin}; kwargs...) = LakeParameters{Martin}(; kwargs...)

function Base.show(io::IO, ::MIME"text/plain", p::LakeParameters{M}) where {M}
    println(io, "Parameters for lake dynamics ($(string(M)) model):")
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
    if M <: Martin
        println(
            io,
            "Vegetation rates. Growth: $(p.rv) day⁻¹, mortality: $(p.mv) day⁻¹, competition: $(p.cv) m²",
        )
    elseif M <: Scheffer
        println(
            io,
            "Maximum vegetation coverage: $(p.K)%",
        )
    end
end

@with_kw_noshow mutable struct LakeState
    @deftype Float64
    # Defaulting to Clear Lake State
    nutrients = 0.5
    pike = 2.6
    bream = 25.8
    vegetation = 50.0
end

abstract type LakeDefinition end

struct Clear <: LakeDefinition end
struct Turbid <: LakeDefinition end
struct X1 <: LakeDefinition end
struct X2 <: LakeDefinition end
struct X3 <: LakeDefinition end

LakeState(::Type{Clear}) = LakeState(0.7, 1.8, 20.0, 50.0)
LakeState(::Type{Turbid}) = LakeState(2.5, 0.04, 84.0, 5.4)
LakeState(::Type{X1}) = LakeState(1.1, 0.5, 60, 10)
LakeState(::Type{X2}) = LakeState(0.8, 0.5, 60, 10)
LakeState(::Type{X3}) = LakeState(0.8, 0.2, 65, 5)

function Base.show(io::IO, ::MIME"text/plain", lake::LakeState)
    println(io, "Lake state:")
    @printf(
        io,
        "Nutrient level: %0.2f, vegetation level: %0.2f%%\n",
        lake.nutrients,
        lake.vegetation
    )
    @printf(io, "bream population: %0.2f, pike population: %0.2f\n", lake.bream, lake.pike)
end

