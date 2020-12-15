@testset "Lake State" begin
    model = initialise(experiment = Experiment(nutrient_series = Constant()))
    @test LimnoSES.nutrient_load!(model, model.nutrient_series) == nothing

    model = initialise(experiment = Experiment(nutrient_series = Dynamic()))
    model[1].affectors = 80
    @test model.init_nutrients < LimnoSES.nutrient_load!(model, model.nutrient_series)

    model = initialise(
        experiment = Experiment(
            target_nutrients = 3.0,
            nutrient_series = TransientUp(start_year = 5, post_target_series = Constant()),
        ),
    )
    LimnoSES.nutrient_load!(model, model.nutrient_series)
    @test model.lake.p.nutrients == model.init_nutrients
    model.year = 6
    @test LimnoSES.nutrient_load!(model, model.nutrient_series) ≈ 0.8

    model = initialise(
        experiment = Experiment(
            target_nutrients = 0.1,
            nutrient_series = TransientDown(
                start_year = 5,
                post_target_series = Constant(),
            ),
        ),
    )
    LimnoSES.nutrient_load!(model, model.nutrient_series)
    @test model.lake.p.nutrients == model.init_nutrients
    model.year = 6
    @test LimnoSES.nutrient_load!(model, model.nutrient_series) ≈ 0.6
end
