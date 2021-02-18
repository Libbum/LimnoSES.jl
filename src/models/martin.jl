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

"""
    lake_initial_state(nutrients, bream, pike, vegetation, Martin)

Provides initial conditions of the lake with specified values.
"""
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

"""
    lake_initial_state(nutrients, <:LakeDefinition, Martin)

A special override that returns interpolated results from precaclulated `Clear` and
`Turbid` bifurcation results. Not as precise as the preset conditions, since the
numbers do not come directly from the analytical solution, but close.
"""
function lake_initial_state(
    nutrients::Float64,
    ::Type{L},
    ::Type{Martin};
    kwargs...,
) where {L<:LakeDefinition}
    initial_state = interpolated_position(nutrients, L)
    (initial_state, MartinParameters(; nutrients = nutrients, kwargs...))
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


function interpolated_position(nutrients::Float64, ::Type{Turbid})
    @assert 1.04 <= nutrients <= 4.0
    [turbid_b(nutrients), turbid_p(nutrients), turbid_v(nutrients)]
end

function interpolated_position(nutrients::Float64, ::Type{Clear})
    @assert 0.0 <= nutrients <= 2.49
    [clear_b(nutrients), clear_p(nutrients), clear_v(nutrients)]
end

# Higher order interpolations were a bit jumpy on the ends. Since we account for this already in the
# grid, there's no real point doing much more than linear interpolation in these data.
const turbid_n = [1.04, 1.06, 1.08, 1.1, 1.12, 1.14, 1.16, 1.18, 1.2, 1.22, 1.24, 1.26, 1.28, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2, 2.3, 2.4, 2.8, 2.9, 3.0, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 4.0]
const turbid_b = LinearInterpolation([62.8433, 64.7811, 65.812, 66.5967154617846, 67.256, 67.8374, 68.3651, 68.8529, 69.3096380295164, 69.7411, 70.1515, 70.5439, 70.9205, 71.2830815128419, 72.927620226924, 74.3575735324184, 75.6261770482514, 76.7652279581881, 77.7965051730699, 78.7361588920137, 79.5967630382622, 80.3884228650353, 81.1194401014282, 81.7967455181591, 82.4261974404837, 84.5557605975222, 85.0087274579361, 85.4355006715746, 85.838305423903, 86.2191189576847, 86.5797047356448, 86.9216409781937, 87.2463446598708, 87.5550918073417, 87.849034761985, 88.1292169339137, 88.3965854697749, 88.6520021756033], turbid_n)
const turbid_p = LinearInterpolation([0.467635, 0.324727, 0.264457, 0.226438572671889, 0.199488, 0.179158, 0.163257, 0.150262, 0.139566501222224, 0.130573, 0.122817, 0.116197, 0.110491, 0.105282876267212, 0.086680414110511, 0.075007876580953, 0.066965656681847, 0.06106181970993, 0.056627123629523, 0.053158110844447, 0.05023878194799, 0.048013362468672, 0.046125185620789, 0.044221413526291, 0.042868037308363, 0.038674849804663, 0.038099615841367, 0.037304090525497, 0.036805912699434, 0.036048380454724, 0.035464861024496, 0.034753892992486, 0.034831406585964, 0.034185163193823, 0.03418612062571, 0.033622695610838, 0.032871258345589, 0.032617613483335], turbid_n)
const turbid_v = LinearInterpolation([10.7297, 10.1524, 9.86357, 9.6515996372934, 9.47861, 9.32976, 9.1976, 9.07784, 8.96776090326038, 8.86554, 8.76989, 8.67984, 8.59468, 8.51383001117352, 8.16073696425393, 7.87085225645183, 7.62612135404186, 7.4157645933494, 7.2325673056776, 7.07136843964007, 6.92831478514543, 6.80044251320062, 6.68542064458636, 6.58138361478245, 6.48681686627753, 6.18128018305646, 6.11902788139653, 6.0612162952174, 6.00738633014564, 5.95714022580627, 5.91013159862657, 5.86605737616413, 5.82465121270593, 5.78567807610134, 5.74892976796485, 5.71422119441633, 5.68138724304635, 5.6502801549636], turbid_n)

const clear_n = [0.0, 0.04, 0.06, 0.08, 0.1, 0.12, 0.14, 0.16, 0.18, 0.2, 0.22, 0.24, 0.26, 0.28, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2, 2.3, 2.4, 2.42, 2.44, 2.46, 2.48, 2.49]
const clear_b = LinearInterpolation([0.0, 7.19822, 10.2447, 12.7489, 14.3417899783703, 15.1403, 15.6098, 15.9564, 16.2464, 16.5043680973213, 16.7416, 16.9638, 17.1743, 17.3752, 17.5681143534832, 18.4409411744765, 19.2038264444943, 19.8895014439516, 20.5171998487337, 21.0999740586095, 21.6473927297074, 22.1668544296341, 22.6643378784209, 23.1448798085877, 23.6129093438797, 24.0725068928104, 24.5276307687052, 24.9823468293504, 25.4411004976985, 25.9090895977944, 26.3928443866286, 26.9012392076907, 27.4474789812928, 28.0536139494919, 28.7632478716902, 29.6944205304346, 29.9376, 30.2195, 30.5678, 31.0733, 31.6065], clear_n)
const clear_p = LinearInterpolation([0.0111003, 0.0142037, 0.023943, 0.0485642, 0.105562347388399, 0.190455, 0.282928, 0.374336, 0.462298, 0.546230121593651, 0.626104, 0.702078, 0.774371, 0.843219, 0.908850307777514, 1.19586574516796, 1.42898170571722, 1.6226301580547, 1.78649633470377, 1.92730359110776, 2.04986983505402, 2.15774343788958, 2.2535990505578, 2.33949577013192, 2.41704615336661, 2.48753542023639, 2.55200022043938, 2.6112914060315, 2.66611434179448, 2.71706494128768, 2.76465434572004, 2.80932964683044, 2.85149627675782, 2.89154743171501, 2.92990689414219, 2.96718342309789, 2.97461, 2.98208, 2.98966, 2.99752, 3.00196], clear_n)
const clear_v = LinearInterpolation([109.96, 103.287, 92.4176, 82.9578, 77.0475035887902, 74.1649, 72.5014, 71.2896, 70.2871, 69.4037351989893, 68.5992, 67.8522, 67.1506, 66.4863, 65.8539683061925, 63.0572420785788, 60.7016894081954, 58.6565110822716, 56.8443323127489, 55.2131743708244, 53.7257083300374, 52.3539004349192, 51.0759395776379, 49.8743098980489, 48.7344963127633, 47.6440564653745, 46.5919019868462, 45.5676811402653, 44.5611694769215, 43.5615585328629, 42.5564678917703, 41.5303333021048, 40.4613483013786, 39.3146251420862, 38.023089573663, 36.4083114241203, 36.0011, 35.536, 34.9723, 34.1743, 33.3579], clear_n)
