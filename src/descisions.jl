module Descisions
using LimnoSES
import LimnoSES: municipalities, lake_dynamics!, lake_initial_state, Intervention
using BlackBoxOptim
import OrdinaryDiffEq
##############################################################
# Predefined objective functions
##############################################################

# These are considerations at a WC level or Municipality level?
# For now, it's going to be at the WC, but some need to be calculated over individual
# Municipality descisions.
min_time(model::ABM) = model.lake.t
min_acceleration(model::ABM) = sum(abs.(model.lake.sol(0:12:(365*model.year), Val{2})))
function min_price(model::ABM)
    # By the time we get here, we're looking at interventions still to do (some may have already been completed, but they have already been budgeted.
    # This descision is only for however much needs to be done in the future.

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

function clear_state(model, s)
    model.year == 60 && return true # Escape if we dont converge after 60 years

    clear = lake_initial_state(Clear, Martin)[1]
    # Due to nutrient differences we will reach slightly different equilibria (reason for 17.5).
    # We also want the system to stabilise a bit, so we wait until the derivatives calm down too.
    # TODO: Root find th accepted distance
    sum(abs2.(model.lake.u - clear)) < 17.5 &&
    sum(abs.(model.lake.sol(model.lake.t, Val{1}))) < 1e-4
end

function create_test_model(model::ABM)
    m = deepcopy(model)
    # Re-initialise certain parameters we need to satisfy in the optimisation
    prob = OrdinaryDiffEq.ODEProblem(lake_dynamics!, model.lake.u, (0.0, Inf), model.lake.p)

    m.lake = OrdinaryDiffEq.init(prob, OrdinaryDiffEq.Tsit5())
    m.year = 0
    m.init_nutrients = model.lake.p.nutrients
    m.init_pike_mortality = model.lake.p.mp

    # Maybe we will need this, not sure just yet.
    push!(m.properties, :true_year_zero => model.year)

    # Drop previous (completed) interventions.
    for municipality in municipalities(m)
        newi = Dict{Int,Vector{Intervention}}()
        for (k, v) in municipality.interventions
            if k == -1
                push!(newi, k => v)
            elseif k - model.year >= 0
                push!(newi, k - model.year => v)
            end
        end
        municipality.interventions = newi
    end
    return m
end

# Thoughts.
# From this point, we may have already done 8 years of interventions. How do we choose to do more or less?
# This must come as part of the descision in `make_descision`. `cost` does not care about this. It has
# campain length paramaters from this time on that it has to play with. That could be zero years or more.
function apply_policies!(x, test)
    xs = Iterators.Stateful(x)

    for municipality in municipalities(test)
        # Update intervention values with new x value
        for intervention in Iterators.flatten(values(municipality.interventions))
            # We must do this in the order of policy range
            if haskey(municipality.policies, typeof(intervention))
                targets = keys(municipality.policies[typeof(intervention)])
                assign = zip(targets, Iterators.take(xs, length(targets)))
                map(t -> setproperty!(intervention, t[1], t[2]), assign)
            end
        end
    end
    return nothing
end

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

function cost(x, test)
    # Next step: search range has everything from the policies section now in search.
    # This means that x is the values associated with all of those results.
    # `test` gives us a copy of model, which we can now edit with the new values in x for
    # each parameter

    #x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7., 8., 9., 10., 11., 12., 13., 14., 15., 16., 17., 18., 19., 20.] # Fake x
    apply_policies!(x, test)

    Agents.step!(test, agent_step!, model_step!, test.target)

    # Taking a `Tuple(objective_functions)` as `objectives`
    return map(o -> o(test), test.objectives)
end

function make_descision!(model::ABM)
    # Create our test model outside of the loop, it will therefore be cut down to
    # approperate points already.
    test = create_test_model(model)

    objective_dimension = length(test.objectives)

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

    result = bboptimize(
        x -> cost(x, test),
        Method = :borg_moea,
        FitnessScheme = ParetoFitnessScheme{objective_dimension}(is_minimizing = true),
        SearchRange = search,
        MaxTime = 60, # We'll hardcode a timer for now, this can be altered in the future
    #    TraceMode = :silent,
    )

    x = best_candidate(result)

    apply_policies!(x, test)
    update_true_model!(test, model)
    return nothing
end

end # module
