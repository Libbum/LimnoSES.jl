export min_time,
    appropriate_vegetation,
    min_acceleration,
    min_cost,
    clear_state,
    managed_clear_eutrophic,
    make_decision!

##############################################################
# Predefined objective functions
##############################################################

"""
    min_time(model)

Objective function that returns the time of the model at the end of a run. If a target
function is interested in moving from one state to the next in the quickest amount of
time, this is a useful objective.
"""
min_time(model::ABM) = model.lake.t / 365.0

"""
    min_acceleration(model)

Objective function that returns the sum of the absolute value of the second derivative of
all lake variables. Span is from start of the optimisation to the final `model.year`
with monthly increments.

Helps to mitigate large spikes in transitions.
"""
min_acceleration(model::ABM) = sum(abs.(model.lake.sol(model.lake.sol.t, Val{2})))

"""
    min_cost(model)

Objective function that returns a "cost" of future `Planting` and `Trawling`
interventions, which ultimately is just a sum of all proposed rates.

!!! note

    When using `nutrient_series = Noise(...)` and only the `min_cost` objective,
    `opt_replicates` *must* be large (`≳ 10`), since the noise process may cause the
    optimiser to identify a solution in theory but fail in practice. The solution to
    failing meet the target scenario in this case is increase `opt_replicates` and retry.
"""
function min_cost(model::ABM)
    # By the time we get here, we're looking at interventions still to do (some may have already been completed, but they have already been budgeted.
    # This decision is only for however much needs to be done in the future.

    # Our budget is not pinned to money directly, but there is an assumed cost based on years to implement at the given rate.
    budget = 0.0

    # Get all Trawling and Planting actions. We assume there is no municipal cost for WastewaterTreatment -> that cost is shifted to the Household for now
    # We also assume no (monetary) cost for Angling, which neglects revenue raised by licensing for the moment.
    for municipality in municipalities(model)
        interventions = vcat(values(municipality.interventions)...)
        plant = Iterators.filter(i -> i isa Planting, interventions)
        trawl = Iterators.filter(i -> i isa Trawling, interventions)

        isempty(plant) || (budget += sum(p -> p.rate * p.cost, plant))
        isempty(trawl) || (budget += sum(t -> t.rate * t.cost, trawl))
    end
    # Above assumes weighting is different for municipalities. If that ends up not to be the case, we can grab all active interventions regardless of municipality with
    # `interventions = merge(vcat, (m.interventions for m in municipalities(model))...)`
    # To simplify the above loop.

    return budget
end

"""
    appropriate_vegetation(model)

Objective function that returns a penalty if vegetation is higher than an operational
density of 60. Higher densities cause recreational issues that are considered
unacceptable.
"""
appropriate_vegetation(model::ABM) = sum(model.lake.sol[3,model.lake.sol[3, :] .> 60.0])

##############################################################
# Predefined target functions
##############################################################

"""
    clear_state(model, s)

Targets the clear lake steady state, with an extra stopping condition if that state was
not reached within 100 years.

Calculated via instantaneous comparisons at latest model time of all lake variables, with
an additional check to verify a near-zero first derivative.

**NOTE:** This target is hard coded to the default `Martin` parameters.
"""
function clear_state(model, s)
    s >= 100 && return true # Escape if we dont converge after 100 years

    # We also want the system to stabilise a bit, so we wait until the derivatives calm down too.
    # That cutoff can be a complication with noisy nutrients, so we relax the criteria in that case.
    if model.nutrient_series isa Noise &&
       hasfield(typeof(model.nutrient_series.process.dist), :σ)
        cutoff = model.nutrient_series.process.dist.σ
    else
        cutoff = 5e-4
    end
    sum(abs.(interpolated_position(model.lake.p.nutrients, Clear) .- model.lake.u,)) <
    cutoff && sum(abs.(model.lake.sol(model.lake.t, Val{1}))) < cutoff
end

"""
    managed_clear_eutrophic(model, s)

Targets the `T3` state, which is a high nutrient (`N>=3`), unstable state with a high
pike population. Will stop at 100 years if not successful.

**Note:** For the moment this targets the region of T3, not the explicit starting point.
"""
function managed_clear_eutrophic(model, s)
    s >= 100 && return true # Escape if we dont converge after 100 years

    B, P, V = model.lake.u

    P >= 3.5 && V > B
end

##############################################################
# Optimisation capacity
##############################################################

"""
    create_test_model(model)

Creates a complete copy of the current model, with a modified set of interventions.
All "completed" interventions (i.e. ones that have happened in the models' past) are
ignored. This test model is then used in the optimisation procedure.
"""
function create_test_model(model::ABM)
    m = deepcopy(model)

    push!(m.properties, :test => true)

    # Drop previous (completed) interventions.
    for municipality in municipalities(m)
        newi = Dict{Int,Vector{Intervention}}()
        for (k, v) in municipality.interventions
            if k == -1
                push!(newi, k => v)
            elseif k - model.year >= 0 && (
                (
                    model.policy.current_term_only &&
                    k <= model.year + model.policy.every - 1
                ) || !model.policy.current_term_only
            )
                # We also drop future interventions that are outside
                # the policy window if such a flag is active.
                push!(newi, k - model.year => v)
            end
        end
        municipality.interventions = newi
    end
    return m
end

"""
    apply_policies!(x, test::ABM)

Applies new test values to all active intervention properties. Is used before each
optimisation call, but also to finalise the decision process via a `best_candidate`
call.
"""
function apply_policies!(x, test)
    xs = Iterators.Stateful(x)

    for municipality in municipalities(test)
        # Update intervention values with new x value
        for intervention in Iterators.flatten(values(municipality.interventions))
            # We must do this in the order of policy range
            if haskey(municipality.policies, typeof(intervention))
                targets = keys(municipality.policies[typeof(intervention)])
                assign = collect(zip(targets, Iterators.take(xs, length(targets))))
                map(t -> setproperty!(intervention, t[1], t[2]), assign)
            end
        end
    end
    return nothing
end

"""
    update_true_model!(test, model)

Reconstructs each municipalities `interventions` property in the model after a successful
optimisation run. Be careful with the model order here, as there's no simple way to
differentiate the two of them via types.
"""
function update_true_model!(test::ABM, model::ABM)
    # Both models have the same municipality ids
    for mid in (m.id for m in municipalities(model))
        for (k, v) in test[mid].interventions
            if k == -1
                # "Always on" values can be replaced directly
                model[mid].interventions[k] = test[mid].interventions[k]
            else
                model[mid].interventions[k+model.year] = test[mid].interventions[k]
            end
        end
    end
    return nothing
end

"""
    cost(x, u0, p, test::ABM)

Optimization function. To be used in in conjunction with the `bboptimize` call only.
Needs to be overloaded slightly, since we want to reset the lake dynamics at each call,
so `model.lake.u` and `model.lake.p` are expected to be passed into the second and third
variables respectively, with the cut down "test" version of the model being the last
value.
"""
function cost(x, u0::Vector{Float64}, p::L, test::ABM) where {L<:LakeParameters}
    # Re-initialise certain parameters we need to satisfy in the optimisation
    prob = OrdinaryDiffEq.ODEProblem(lake_dynamics!, u0, (0.0, Inf), p)

    test.lake = OrdinaryDiffEq.init(prob, OrdinaryDiffEq.Tsit5())
    if haskey(test.properties, :nutrient_stabilise)
        test.nutrient_stabilise -= test.year
    end
    test.year = 0
    test.init_nutrients = p.nutrients
    test.init_pike_mortality = p.mp

    # Search range has everything from the policies section now in search.
    # This means that x is the values associated with all of those results.
    # `test` gives us a copy of model, which we can now edit with the new values in x for
    # each parameter
    apply_policies!(x, test)

    if test.policy.opt_replicates > 0
        results = Agents.Distributed.pmap(
            j -> calculate_objectives(deepcopy(test)),
            test.policy.opt_pool,
            1:test.policy.opt_replicates,
        )
        return Tuple(mean.(Iterators.zip(results...)))
    else
        return calculate_objectives(test)
    end
end

function calculate_objectives(test)
    if test.nutrient_series isa Noise
        # Don't assume we use the same seed
        seed!(test)
        Random.seed!(test.nutrient_series.process.rng)
    end

    Agents.step!(test, agent_step!, model_step!, test.policy.target)
    objectives = first.(test.policy.objectives)
    if test.policy.target(test, 1)
        return map(o -> o(test), objectives)
    else
        # Dramatically penalise this result, as it failed to
        # reach the target before cutoff.
        return map(o -> o(test) * 1e2, objectives)
    end
end

"""
    make_decision!(model)

Runs the optimisation routine, calling on policy ranges set via [`policy`](@ref).
Decisions are made only from the year of the call onwards.
"""
function make_decision!(model::ABM)
    # Create our test model outside of the loop, it will therefore be cut down to
    # appropriate points already.
    test = create_test_model(model)

    objective_dimension = length(test.policy.objectives)
    w = last.(test.policy.objectives)

    # We only need the tuples for the search range here. So long as we use the same
    # scheduler, there's no need to worry about anything else on the other side
    # of the function guard. The only nuance is to iterate through each municipality
    # in order so that we replicate the ranges of everything correctly.
    search = Tuple{Float64,Float64}[]
    for municipality in municipalities(test)
        for intervention in Iterators.flatten(values(municipality.interventions))
            if haskey(municipality.policies, typeof(intervention))
                append!(search, collect(municipality.policies[typeof(intervention)]))
            end
        end
    end

    # No need to optimise if there are no more interventions
    isempty(search) && return nothing

    if model.policy.trace_mode != :silent
        word = model.year == model.policy.start ? "Starting" : "Adjusting"
        println("$(word) policy decisions in year $(model.year)")
    end

    result = bboptimize(
        x -> cost(x, model.lake.u, model.lake.p, test),
        Method = :borg_moea,
        FitnessScheme = ParetoFitnessScheme{objective_dimension}(
            is_minimizing = true,
            aggregator = f -> weightedfitness(f, w),
        ),
        SearchRange = search,
        MaxSteps = model.policy.max_steps,
        MaxTime = model.policy.max_time,
        TraceMode = model.policy.trace_mode,
        TraceInterval = 10,
    )

    x = best_candidate(result)

    apply_policies!(x, test)
    update_true_model!(test, model)

    return nothing
end

"""
    weightedfitness(f, weights)

Handle objective weights. Should be used as an `aggregator` in `bboptimize`.
"""
weightedfitness(f, w) = sum(f .+ w)

