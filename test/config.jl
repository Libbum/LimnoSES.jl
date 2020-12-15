@testset "Config" begin
    clearm = lake_initial_state(Clear, Martin)
    clears = lake_initial_state(Clear, Scheffer)
    @test length(clearm[1]) == 3
    @test length(clears[1]) == 2
    @test clears[2].K == 100.0
    @test_throws ErrorException clearm[2].K
    clears = lake_initial_state(Clear, Scheffer; K = 50.0)
    @test clears[2].K == 50.0
end
