@testset "Evolve" begin
    model = initialise()

    @test length(collect(households(model))) == model[1].households
    @test length(collect(households(model[1], model))) == model[1].households

    @test length(collect(municipalities(model))) == 1

    @test LimnoSES.active_interventions(model[1], 1) == [WastewaterTreatment()]
end
