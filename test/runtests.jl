using Test, LimnoSES

@testset "Planning" begin
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
end


