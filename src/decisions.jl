export min_time, min_acceleration, min_cost, clear_state, managed_clear_eutrophic, make_decision!

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
min_acceleration(model::ABM) = sum(abs.(model.lake.sol(0:12:(365*model.year), Val{2})))

"""
    min_cost(model)

Objective function that returns a "cost" of future `Planting` and `Trawling`
interventions, which ultimately is just a sum of all proposed rates.

In future it will be possible to apply a weight to each of the interventions as one is
most likely more costly than the other.
"""
function min_cost(model::ABM)
    # By the time we get here, we're looking at interventions still to do (some may have already been completed, but they have already been budgeted.
    # This decision is only for however much needs to be done in the future.

    # Our budget is not pinned to money directly, but there is an assumed cost based on years to implement at the given rate.
    # This should probably be weighted in the future, since different interventions most likely cost more than others.
    budget = 0.0

    # Get all Trawling and Planting actions. We assume there is no municipal cost for WastewaterTreatment -> that cost is shifted to the Household for now
    # We also assume no (monetary) cost for Angling, which neglects revenue raised by licensing for the moment.
    for municipality in municipalities(model)
        interventions = vcat(values(municipality.interventions)...)
        # This could be done in one go, but is separated so we can implement weights later.
        plant = Iterators.filter(i -> i isa Planting, interventions)
        trawl = Iterators.filter(i -> i isa Trawling, interventions)

        # 1.0 is where the future weight should be assigned
        isempty(plant) || (budget += sum(p -> p.rate, plant) * 1.0)
        isempty(trawl) || (budget += sum(t -> t.rate, trawl) * 1.0)
    end
    # Above assumes weighting is different for municipalities. If that ends up not to be the case, we can grab all active interventions regardless of municipality with
    # `interventions = merge(vcat, (m.interventions for m in municipalities(model))...)`
    # To simplify the above loop.

    return budget
end

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
    model.year == 100 && return true # Escape if we dont converge after 100 years

    B, P, V = model.lake.u

    # Based on bifurcation analysis: for a clear state, we need
    # V >= 33.4, B < 31.6 and if n > 1 then P > 0.5
    # We also want the system to stabilise a bit, so we wait until the derivatives calm down too.
    B < 31.6 &&
    V >= 33.4 &&
    (model.lake.p.nutrients > 1.0 ? P > 0.5 : true) &&
    sum(abs.(model.lake.sol(model.lake.t, Val{1}))) < 5e-4
end

"""
    managed_clear_eutrophic(model, s)

Targets the `T3` state, which is a high nutrient (`N>=3`), unstable state with a high
pike population. Will stop at 100 years if not successful.

**Note:** For the moment this targets the region of T3, not the explicit starting point.
"""
function managed_clear_eutrophic(model, s)
    model.year == 100 && return true # Escape if we dont converge after 100 years

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
    test.year = 0
    test.init_nutrients = p.nutrients
    test.init_pike_mortality = p.mp

    # Search range has everything from the policies section now in search.
    # This means that x is the values associated with all of those results.
    # `test` gives us a copy of model, which we can now edit with the new values in x for
    # each parameter
    apply_policies!(x, test)

    Agents.step!(test, agent_step!, model_step!, test.policy.target)

    return map(o -> o[1](test), test.policy.objectives)
end

"""
    make_decision!(model)

Runs the optimisation routine, calling on policy ranges set via [`policy`](@ref).
Decisions are made only from the year of the call onwards.

## Keywords

A few keywords that can be sent to the `bboptimize` routine have been made available
here:

- `MaxTime = 300`, a hard time limit for the optimiser to run.
- `TraceMode = :compact`, logging output control. Other options are `:silent` and
`:verbose`.
"""
function make_decision!(model::ABM; MaxTime = 300, TraceMode = :compact)
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

    if TraceMode != :silent
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
        MaxTime = MaxTime,
#        NThreads = max(Threads.nthreads() - 1, 1),
        TraceMode = TraceMode,
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
weightedfitness(f, w) = sum(map((fi, wi) -> fi * wi, f, w))

