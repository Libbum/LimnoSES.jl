@testset "Reporting" begin
    model = initialise(lake_setup = lake_initial_state(Clear, Scheffer))

    @test nutrients(model) == model.lake.p.nutrients
    @test vegetation(model.lake) == [50.0]
    @test vegetation([model.lake.u[1]], model.lake.p) == [50.0]

    model = initialise(
        experiment = Experiment(nutrient_series = Dynamic()),
        lake_setup = lake_initial_state(Clear, Martin),
        municipalities = Dict(
            "main" => (
                Governance(
                    houseowner_type = Enforced(),
                    interventions = planner(plan(WastewaterTreatment)),
                ),
                100,
            ),
        ),
    )
    @test upgrade_efficiency(model) == 0
end
