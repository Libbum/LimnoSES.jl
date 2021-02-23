# Patch for Agents that allows us to run parallel_replicates without having a solution for Agents.jl#415
# Assumes a Distributed setup.
export replicates

function seeded(model)
    m = deepcopy(model)
    seed!(m)
    if m.nutrient_series isa Noise
        Random.seed!(m.nutrient_series.process.rng)
    end
    return m
end

function replicates(model::ABM, agent_step!, model_step!, n, replicates; kwargs...)

    # Generally, it will be better to solve world replicates in paralell since they have a longer spool time.
    # So we steal from the opt_pool as much as possible. It needs to have at least one worker though otherwise it'll block (I think).
    println("Separating $(length(model.policy.opt_pool)) workers into pools..")
    if model.policy.opt_replicates > 0
        # Let optimiser know to run from a partial pool
        # Generally, it will be better to solve world replicates in paralell since they have a longer spool time.
        # So we steal from the opt_pool as much as possible. It needs to have at least one worker though otherwise it'll block (I think).
        if replicates < Agents.Distributed.nworkers()
            # steal enough
            pool = Agents.Distributed.WorkerPool(Agents.Distributed.workers()[1:replicates])
            model.policy.opt_pool =
                Agents.Distributed.WorkerPool(Agents.Distributed.workers()[replicates+1:end])
        else
            # steal everything
            pool = Agents.Distributed.WorkerPool(Agents.Distributed.workers())
            model.policy.opt_pool = Agents.Distributed.WorkerPool()
        end
    else
        # We can run on the optimisers pool, since it doesn't need it.
        pool = model.policy.opt_pool
    end
    println("Using $(length(pool)) on replicates, $(length(model.policy.opt_pool)) on optimiser throws.")
    all_data = Agents.Distributed.pmap(
        j -> Agents._run!(seeded(model), agent_step!, model_step!, n; kwargs...),
        pool,
        1:replicates,
    )

    df_agent = Agents.DataFrame()
    df_model = Agents.DataFrame()
    for (rep, d) in enumerate(all_data)
        Agents.replicate_col!(d[1], rep)
        Agents.replicate_col!(d[2], rep)
        append!(df_agent, d[1])
        append!(df_model, d[2])
    end

    return df_agent, df_model
end
