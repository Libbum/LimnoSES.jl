export Household,
    Introverted,
    Social,
    Enforced,
    Pike,
    Nutrients,
    Constant,
    Dynamic,
    Noise,
    TransientUp,
    TransientDown,
    Decision,
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
    S1,
    S2,
    S3,
    T1,
    T2,
    T3,
    Experiment,
    LakeParameters

abstract type Intervention end
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
    interventions::Dict{Integer,Vector{Intervention}} # Set of interventions municipality will act on
    policies::Dict{Type{<:Intervention},NamedTuple} # Decision parameters, subject to change
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
    interventions::Dict{Integer,Vector{Intervention}} = Dict(-1 => [WastewaterTreatment()]) # Set of interventions municipality will act on
    # Additions for descision making. Subject to change
    policies::Dict{Type{<:Intervention},NamedTuple} =
        Dict{Type{<:Intervention},NamedTuple}()
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

"""
    Constant()

Nutrient level remains constant at the level of `init_nutrients`.
"""
struct Constant <: NutrientSeries end

"""
    Dynamic()

Nutrient runoff is managed by the municipality by incentivising households to upgrade
sewage systems that seep P into the lake.
"""
struct Dynamic <: NutrientSeries end


"""
    Noise(process, min, max)

Noise process given by DiffEqNoiseProcess.jl. For the moment this does not connect to
the actual start time or `init_nutrients` value, so these must be manually duplicated
here. Will be fixed in the future. `min` and `max` nutrient values can also be applied.
"""
@with_kw struct Noise <: NutrientSeries
    process::NoiseProcess = GeometricBrownianMotionProcess(0.0,0.05,0.0,2.0)
    min::Float64 = 0.0
    max::Float64 = 20.0
end

"""
    TransientUp(;start_year = 11, post_target_series = Constant())

Synthetic nutrient profile that alters lake dynamics regardless of municipal management.

- `start_year`: year when nutrients begin to increase with a rate of `nutrient_change`.
- `post_target_series`: behaviour after `target_nutrients` value is reached.
    Default is `TransientDown(start_year = 0, post_target_series = Constant())`

!!! warning

    Post target series selection must include a final `Constant` phase, otherwise an
    infinite recursion cascade will occur.
"""
@with_kw struct TransientUp <: NutrientSeries
    start_year::Integer = 11
    post_target_series::NutrientSeries =
        TransientDown(start_year = 0, post_target_series = Constant())
end

"""
    TransientDown(;start_year = 11, post_target_series = Constant())

Synthetic nutrient profile that alters lake dynamics regardless of municipal management.

- `start_year`: year when nutrients begin to decrease with a rate of `nutrient_change`.
- `post_target_series`: behaviour after `target_nutrients` value is reached.
    Default is `TransientUp(start_year = 0, post_target_series = Constant())`

!!! warning

    Post target series selection must include a final `Constant` phase, otherwise an
    infinite recursion cascade will occur.
"""
@with_kw struct TransientDown <: NutrientSeries
    start_year::Integer = 11
    post_target_series::NutrientSeries =
        TransientUp(start_year = 0, post_target_series = Constant())
end

"""
## Keywords

A few keywords that can be sent to the `bboptimize` routine have been made available
here:

- `max_time = 300`, a hard time limit for the optimiser to run.
- `trace_mode = :compact`, logging output control. Other options are `:silent` and
`:verbose`.
"""
@with_kw mutable struct Decision
    start::Int = 1 # year when first optimisation is completed
    every::Int = 5 # year when next optimisation is completed (if target not met)
    current_term_only::Bool = true # If true, only optimise the next X years
    objectives::NTuple{N,Tuple{Function,Float64}} where {N} = ((min_time, 1.0),)
    target::Function = clear_state
    # Optimiser settings
    max_time::Float64 = 300.0
    trace_mode::Symbol = :compact
    opt_replicates::Int = 0
    opt_pool::Agents.Distributed.WorkerPool = Agents.Distributed.default_worker_pool()
end

# Properties of the experiment. For now this is a drop in for GUI values
# TODO: Some of these may need to be put under Governance
@with_kw mutable struct Experiment
    identifier::String = "biggs-baseline" # String for the moment. Might want to reconsider this in the future.
    # Related to lake
    # TODO: Perhaps the Water Council can set these values? Then all municipalities adhere to them.
    pike_expectation::Float64 = 1.4
    target_nutrients::Float64 = 0.7
    nutrient_series::NutrientSeries = Constant()
    nutrient_stabilise::Int = 0 # Used in BrownianBridge noise processes
    nutrient_change::Float64 = 0.1
    critical_nutrients::Float64 = 3.0
    recycling_rate::Float64 = 0.1
    max_sewage_water::Float64 = 0.1
    # Additions for descision making. Subject to change
    policy::Decision = Decision()
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

struct WastewaterTreatment <: Intervention end
@with_kw_noshow mutable struct Planting <: Intervention
    rate::Float64 = 1e-4
    cost::Float64 = 1.0 # Cost is given here as a ratio. Defualt is 1:1.
end
@with_kw_noshow mutable struct Trawling <: Intervention
    rate::Float64 = 5e-4
    cost::Float64 = 1.0
end
@with_kw_noshow mutable struct Angling <: Intervention
    rate::Float64 = 2.25e-4 # 10% of default rate
end

# Lake dynamics
abstract type LakeModel end
abstract type LakeParameters end
abstract type LakeDefinition end

struct Clear <: LakeDefinition end
struct Turbid <: LakeDefinition end
struct X1 <: LakeDefinition end
struct X2 <: LakeDefinition end
struct X3 <: LakeDefinition end

struct S1 <: LakeDefinition end
struct S2 <: LakeDefinition end
struct S3 <: LakeDefinition end
struct T1 <: LakeDefinition end
struct T2 <: LakeDefinition end
struct T3 <: LakeDefinition end

function lake_initial_state(
    ::Type{L},
    ::Type{M};
    kwargs...,
) where {L<:LakeDefinition,M<:LakeModel}
    nutrients, initial_state = preset_conditions(L, M)
    (initial_state, LakeParameters(M, nutrients; kwargs...))
end

