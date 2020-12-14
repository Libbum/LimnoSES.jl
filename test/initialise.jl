@testset "Initialise" begin
    model = initialise()
    @test sort(collect(keys(model.properties))) == [
        :critical_nutrients,
        :identifier,
        :init_nutrients,
        :init_pike_mortality,
        :lake,
        :max_sewage_water,
        :nutrient_change,
        :nutrient_series,
        :outcomes_upgraded_households_sum,
        :outcomes_year_of_full_upgrade,
        :outcomes_year_when_desired_level_is_back,
        :outcomes_year_when_desired_pike_is_back,
        :outcomes_year_when_informed,
        :outcomes_year_when_nutrients_became_critical,
        :outcomes_year_when_pike_became_critical,
        :pike_expectation,
        :policy,
        :recycling_rate,
        :target_nutrients,
        :year,
    ]

    @test sort(collect(keys(LimnoSES.type2dict(model.policy)))) ==
          [:current_term_only, :every, :objectives, :start, :target]
    @test sort(collect(keys(LimnoSES.type2dict(model.policy; prefix = "x")))) ==
          [:x_current_term_only, :x_every, :x_objectives, :x_start, :x_target]

    @testset "plan" begin
        schedule = plan(Angling)
        @test collect(keys(schedule)) == [-1]
        @test length(schedule) == 1
        @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
        @test count(_ -> true, Iterators.flatten(values(schedule))) == 1
        @test all(i.rate ≈ 0.000225 for i in Iterators.flatten(values(schedule)))
        schedule = plan(Angling; rate = 2.5e-3)
        @test collect(keys(schedule)) == [-1]
        @test length(schedule) == 1
        @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
        @test count(_ -> true, Iterators.flatten(values(schedule))) == 1
        @test all(i.rate ≈ 0.0025 for i in Iterators.flatten(values(schedule)))
        schedule = plan(Angling, 7; rate = 3.2e-3)
        @test collect(keys(schedule)) == [7]
        @test length(schedule) == 1
        @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
        @test count(_ -> true, Iterators.flatten(values(schedule))) == 1
        @test all(i.rate ≈ 0.0032 for i in Iterators.flatten(values(schedule)))
        schedule = plan(Angling, 3:5)
        @test sort(collect(keys(schedule))) == [3, 4, 5]
        @test length(schedule) == 3
        @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
        @test count(_ -> true, Iterators.flatten(values(schedule))) == 3
        @test all(i.rate ≈ 0.000225 for i in Iterators.flatten(values(schedule)))
        schedule =
            plan(Angling, [(period = 1:4,), (year = 5, rate = 7.2e-3), (period = 7:9,)])
        @test sort(collect(keys(schedule))) == [1, 2, 3, 4, 5, 7, 8, 9]
        @test length(schedule) == 8
        @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
        @test count(_ -> true, Iterators.flatten(values(schedule))) == 8
        @test all(
            i.rate ≈ 0.000225
            for i in Iterators.flatten(v for (k, v) in pairs(schedule) if k != 5)
        )
        @test all(
            i.rate ≈ 0.0072
            for i in Iterators.flatten(v for (k, v) in pairs(schedule) if k == 5)
        )
        # An edge case:
        @test length(plan(Angling, [(year = 1, rate = 1), (year = 2,)])) == 2
        @test length(plan(Angling, [(year = 1,), (year = 2,)])) == 2
        @test length(plan(Angling, [(year = 1,)])) == 1

        @test_throws AssertionError plan(Angling, [(rate = 1,)])
        @test_throws MethodError plan(Angling, [(year = 1,)]; rate = 1e-3)
    end
    @testset "planner" begin
        interventions = planner(plan(Angling))
        schedule = plan(Angling)
        @test collect(keys(schedule)) == collect(keys(interventions))
        @test length(schedule) == length(interventions)
        @test collect(i isa Angling for i in Iterators.flatten(values(schedule))) ==
              collect(i isa Angling for i in Iterators.flatten(values(interventions)))
        @test count(_ -> true, Iterators.flatten(values(schedule))) ==
              count(_ -> true, Iterators.flatten(values(interventions)))
        @test all(i.rate ≈ 0.000225 for i in Iterators.flatten(values(interventions)))

        interventions = planner(plan(Planting, 2; rate = 5e-3), plan(Trawling, 1:3))
        @test sort(collect(keys(interventions))) == [1, 2, 3]
        @test length(interventions) == 3
        @test count(_ -> true, Iterators.flatten(values(interventions))) == 4
        @test all(
            i isa Planting || i isa Trawling
            for i in Iterators.flatten(values(interventions))
        )
        @test count(i -> i isa Planting, Iterators.flatten(values(interventions))) == 1

        @test_throws AssertionError planner(plan(Angling), plan(Angling, 7))
    end
    @testset "scan" begin
        default_planting = (threshold = (5.0, 60.0), rate = (0.001, 0.01))
        @test scan(Planting) == Dict(Planting => default_planting)
        @test LimnoSES.default_policy(Planting) == default_planting
        @test scan(Planting; rate = (0.0, 1.0)) ==
              Dict(Planting => (threshold = (5.0, 60.0), rate = (0.0, 1.0)))
        default_trawling = (threshold = (40.0, 80.0), rate = (0.0001, 0.01))
        @test scan(Trawling) == Dict(Trawling => default_trawling)
        @test LimnoSES.default_policy(Trawling) == default_trawling
        @test scan(Trawling; rate = (0.0, 1.0)) ==
              Dict(Trawling => (threshold = (40.0, 80.0), rate = (0.0, 1.0)))
        default_angling = (rate = (2.25e-3, 2.7e-3),)
        @test scan(Angling) == Dict(Angling => default_angling)
        @test LimnoSES.default_policy(Angling) == default_angling
        @test scan(Angling; rate = (0.0, 1.0)) == Dict(Angling => (rate = (0.0, 1.0),))
    end
    @testset "policy" begin
        plant = scan(Planting)
        pol = policy(scan(Planting))
        @test pol == plant

        pol = policy(scan(Planting), scan(Angling))
        @test all(map(k->k in [Angling, Planting], collect(keys(pol))))
    end
    @testset "objective" begin
        obj = objective(min_time)
        @test typeof(obj) <: Tuple{<:Function,Float64}
        @test last(obj) == 1.0

        obj = objective(min_time, 5)
        @test typeof(obj) <: Tuple{<:Function,Int}
        @test last(obj) == 5

        obj = objective(min_time, 1.6)
        @test typeof(obj) <: Tuple{<:Function,Float64}
        @test last(obj) == 1.6
    end
    @testset "objectives" begin
        obj = objective(min_time)
        objs = objectives(objective(min_time))
        @test objs[1] == obj

        objs = objectives(objective(min_time), objective(min_cost))
        @test typeof(objs) <: NTuple{N,Tuple{<:Function,Float64}} where {N}
        @test length(objs) == 2
        @test sum(last.(objs)) == 1.0

        objs = objectives(objective(min_time, 57), objective(min_cost, 1.5))
        @test typeof(objs) <: NTuple{N,Tuple{<:Function,Float64}} where {N}
        @test sum(last.(objs)) == 1.0
    end
end

