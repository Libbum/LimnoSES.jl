# Patch for Agents that allows us to run parallel_replicates without having a solution for Agents.jl#415
# Assumes a Distributed setup.
export replicates

function seeded(model)
    m = deepcopy(model)
    if m.nutrient_series isa Noise
        Random.seed!(m.nutrient_series.process.rng,rand(UInt64))
    end
    return m
end

function replicates(model::ABM, agent_step!, model_step!, n, replicates; kwargs...)

  all_data = Agents.Distributed.pmap(j -> Agents._run!(seeded(model), agent_step!, model_step!, n; kwargs...),
                  1:replicates)

  df_agent = DataFrame()
  df_model = DataFrame()
  for (rep, d) in enumerate(all_data)
    Agents.replicate_col!(d[1], rep)
    Agents.replicate_col!(d[2], rep)
    append!(df_agent, d[1])
    append!(df_model, d[2])
  end

  return df_agent, df_model
end
