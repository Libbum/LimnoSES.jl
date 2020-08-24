using Test, LimnoSES

@testset "plan" begin
    schedule = plan(Angling)
    @test collect(keys(schedule)) == [-1]
    @test length(schedule) == 1
    @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
    @test count(_->true,Iterators.flatten(values(schedule))) == 1
    @test all(i.rate ≈ 0.000225 for i in Iterators.flatten(values(schedule)))
    schedule = plan(Angling; rate = 2.5e-3)
    @test collect(keys(schedule)) == [-1]
    @test length(schedule) == 1
    @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
    @test count(_->true,Iterators.flatten(values(schedule))) == 1
    @test all(i.rate ≈ 0.0025 for i in Iterators.flatten(values(schedule)))
    schedule = plan(Angling, 7; rate = 3.2e-3)
    @test collect(keys(schedule)) == [7]
    @test length(schedule) == 1
    @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
    @test count(_->true,Iterators.flatten(values(schedule))) == 1
    @test all(i.rate ≈ 0.0032 for i in Iterators.flatten(values(schedule)))
    schedule = plan(Angling, 3:5)
    @test sort(collect(keys(schedule))) == [3, 4, 5]
    @test length(schedule) == 3
    @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
    @test count(_->true,Iterators.flatten(values(schedule))) == 3
    @test all(i.rate ≈ 0.000225 for i in Iterators.flatten(values(schedule)))
    schedule = plan(Angling, [(period = 1:4, ),
                              (year = 5, rate = 7.2e-3),
                              (period = 7:9, )])
    @test sort(collect(keys(schedule))) == [1, 2, 3, 4, 5, 7, 8, 9]
    @test length(schedule) == 8
    @test all(i isa Angling for i in Iterators.flatten(values(schedule)))
    @test count(_->true,Iterators.flatten(values(schedule))) == 8
    @test all(i.rate ≈ 0.000225 for i in Iterators.flatten(v for (k,v) in pairs(schedule) if k != 5))
    @test all(i.rate ≈ 0.0072 for i in Iterators.flatten(v for (k,v) in pairs(schedule) if k == 5))
    @test_throws MethodError plan(Angling, [(rate = 1, )])
    @test_throws MethodError plan(Angling, [(year = 1, )]; rate = 1e-3)
end
