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
    Governance,
    Planting,
    WastewaterTreatment,
    Trawling,
    Angling,
    lake_initial_state,
    Clear,
    Turbid,
    X1,
    X2,
    X3,
    Experiment,
    LakeParameters,
    Martin,
    Scheffer

abstract type Interventions end
abstract type Status end
abstract type Threshold end
abstract type HouseOwner end
abstract type NutrientSeries end

mutable struct Household <: AbstractAgent
    id::Int # The identifier number of the agent
    pos::Tuple{Int,Int} # The x, y location of the agent on a 2D grid
    compliance::Float64 # From willingness to upgrade
    oss::Bool # Is the sewage system upgraded or not?
    information::Bool # Has this agent been told about the upgrade?
    implementation_lag::Int # How long does it take the agent to choose to upgrade?
    municipality::Int # ID of the municipality this household belongs to
end

mutable struct Municipality <: AbstractAgent
    id::Int # The identifier number of the agent
    pos::Tuple{Int,Int} # The x, y location of the agent on a 2D grid
    name::String
    information::Bool # information on state of the lake
    legislation::Bool # legislation power to enforce new rules
    regulate::Bool
    respond_direct::Bool
    threshold_variable::Threshold
    interventions::Vector{Interventions} # Set of interventions municipality will act on
    agents_uniform::Bool # TODO: This is a poorly named bool. Point here is that if this is true, the agents willingness_to_upgrade will be pulled form a uniform distribution.
    houseowner_type::HouseOwner
    willingness_to_upgrade::Float64
    tolerance_level_affectors::Float64
    neighbor_distance::Int
    households::Int
    affectors::Int
end

@with_kw mutable struct Governance
    # Properties
    information::Bool = false # information on state of the lake
    legislation::Bool = false # legislation power to enforce new rules
    # Actions
    regulate::Bool = true
    respond_direct::Bool = false
    threshold_variable::Threshold = Nutrients()
    interventions::Vector{Interventions} = [WastewaterTreatment()] # Set of interventions municipality will act on
    # Related to home owners
    agents_uniform::Bool = false # TODO: This is a poorly named bool. Point here is that if this is true, the agents willingness_to_upgrade will be pulled form a uniform distribution.
    houseowner_type::HouseOwner = Introverted()
    willingness_to_upgrade::Float64 = 0.2
    tolerance_level_affectors::Float64 = 50.0
    neighbor_distance::Int = 3
end

struct Idle <: Status end
struct Running <: Status end
struct Complete <: Status end


struct Pike <: Threshold end
struct Nutrients <: Threshold end


struct Introverted <: HouseOwner end
struct Social <: HouseOwner end
struct Enforced <: HouseOwner end


struct Constant <: NutrientSeries end
struct Dynamic <: NutrientSeries end
struct TransientUp <: NutrientSeries end
struct TransientDown <: NutrientSeries end

# Properties of the experiment. For now this is a drop in for GUI values
# TODO: Some of these may need to be put under Governance
@with_kw mutable struct Experiment
    identifier::String = "biggs-baseline" # String for the moment. Might want to reconsider this in the future.
    # Related to lake
    # TODO: Perhaps the Water Council can set these values? Then all municipalities adhere to them.
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


struct WastewaterTreatment <: Interventions end
@with_kw_noshow mutable struct Planting <: Interventions
    # Welcome to edit
    campaign_length::Int = 3 # Years of a planting campaign
    threshold::Float64 = 20.0
    rate::Float64 = 1e-3
    # Internals, do not edit
    years_active::Int = 0 # Number of years campaign has been active
    status::Status = Idle() # Idicator of activity
    year_when_planting_begins::Int = 0
    #TODO: Separate these out to somewhere else in the monitoring section
    yearly_stock_bream::Vector{Tuple{Float64,Float64}} = [] # density / % increase/decrease of bream
    yearly_stock_vegetation::Vector{Tuple{Float64,Float64}} = [] # density / % increase/decrease of vegetation
end
@with_kw_noshow mutable struct Trawling <: Interventions
    # Welcome to edit
    campaign_length::Int = 3 # Years of a trawling campaign
    threshold::Float64 = 50.0
    rate::Float64 = 1e-3
    # Internals, do not edit
    years_active::Int = 0 # Number of years campaign has been active
    status::Status = Idle() # Idicator of activity
    year_when_trawling_begins::Int = 0
    #TODO: Separate these out to somewhere else in the monitoring section
    yearly_stock_bream::Vector{Tuple{Float64,Float64}} = [] # density / % increase/decrease of bream
    yearly_stock_vegetation::Vector{Tuple{Float64,Float64}} = [] # density / % increase/decrease of vegetation
end
@with_kw_noshow mutable struct Angling <: Interventions
    # Welcome to edit
    rate::Float64 = 2.25e-4 # 10% of default rate
    # Internals, do not edit
    status::Status = Idle()
end


# Lake dynamics
abstract type LakeModel end

struct Scheffer <: LakeModel end
struct Martin <: LakeModel end

# Nutrient range showing bistability in M0 [1,2.1]; M1 [0.7,1.5]
@with_kw_noshow mutable struct LakeParameters{M<:LakeModel}
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
    K = 100 # % maximum vegetation coverage
    rv = 7e-3 # day⁻¹ vetegation growth rate
    cv = 6e-5 # m² intraspecific competition for vetetation
    mv = 7e-3 # day⁻¹ mortality of vegetation
    pv = 0.0 # day planting rate
    tb = 0.0 # day trawling rate
end

LakeParameters(::Type{Scheffer}, nutr; kwargs...) = LakeParameters{Scheffer}(;
    nutrients = nutr,
    H₂ = 10,
    ce = 0.1,
    rv = 0,
    cv = 0,
    mv = 0,
    kwargs...,
)
LakeParameters(::Type{Martin}, nutr; kwargs...) =
    LakeParameters{Martin}(; nutrients = nutr, kwargs...)

function Base.show(io::IO, ::MIME"text/plain", p::LakeParameters{M}) where {M}
    println(io, "Parameters for lake dynamics ($(string(M)) model):")
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
    if M <: Martin
        println(
            io,
            "Vegetation rates. Growth: $(p.rv) day⁻¹, mortality: $(p.mv) day⁻¹, competition: $(p.cv) m²",
        )
    elseif M <: Scheffer
        println(io, "Maximum vegetation coverage: $(p.K)%")
    end
end

abstract type LakeDefinition end

struct Clear <: LakeDefinition end
struct Turbid <: LakeDefinition end
struct X1 <: LakeDefinition end
struct X2 <: LakeDefinition end
struct X3 <: LakeDefinition end

lake_initial_state(nutrients::Float64, bream::Float64, pike::Float64, vegetation::Float64) =
    (nutrients, [bream, pike, vegetation])
lake_initial_state(::Type{Clear}) = (0.7, [15.093, 1.947, 74.333])
lake_initial_state(::Type{Turbid}) = (2.5, [83.085, 0.032, 6.390])
lake_initial_state(::Type{X1}) = (2.2, [60.036,  0.738, 11.654])
lake_initial_state(::Type{X2}) = (1.05, [60.036, 0.738, 11.654])
lake_initial_state(::Type{X3}) = (1.05, [65.984, 0.183, 9.816])
