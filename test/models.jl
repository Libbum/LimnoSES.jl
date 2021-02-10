@testset "Models" begin
    @testset "Scheffer" begin
        setup = lake_initial_state(1.7, 50.0, 30.0, Scheffer)
        @test setup[1] == [50.0, 30.0]
        @test setup[2].nutrients == 1.7

        lp = LakeParameters(Scheffer, 0.9)
        @test typeof(lp) <: LimnoSES.SchefferParameters
        @test lp.nutrients == 0.9

        @test LimnoSES.preset_conditions(Clear, Scheffer) == (0.7, [20.0, 1.8])
        @test LimnoSES.preset_conditions(Turbid, Scheffer) == (2.5, [84.0, 0.04])

        @test sprint(show, "text/plain", lp) ==
              "Parameters for lake dynamics (Scheffer) model):\nNutrient level: 0.9\nImmigration rate (g⋅m⁻²⋅day⁻¹) for bream: 2.0e-5, pike: 2.0e-5\nGrowth rate (day⁻¹) for bream: 0.0075, Predation rate (day⁻¹) of pike: 0.05\nHalf sturation constants: H₁ 0.5, H₂ 10.0%, H₃ 20.0 g⋅m⁻², H₄ 15.0 g⋅m⁻²\nIntraspecific competition constant (g⋅m⁻²⋅day⁻¹) for bream: 7.5e-5, pike: 0.000275\nPike food conversion efficiency to growth: 0.1, Mortalitiy rate (day⁻¹): 0.00225\nMaximum vegetation coverage: 100.0%\n"

        du = [0.0, 0.0]
        LimnoSES.lake_dynamics!(du, [20.0, 1.8], lp, 0.0)
        @test du == [0.008848571428571449, -0.0001209999999999985]
    end
    @testset "Martin" begin
        setup = lake_initial_state(1.7, 50.0, 30.0, 80.0, Martin)
        @test setup[1] == [50.0, 30.0, 80.0]
        @test setup[2].nutrients == 1.7

        lp = LakeParameters(Martin, 0.9)
        @test typeof(lp) <: LimnoSES.MartinParameters
        @test lp.nutrients == 0.9

        @test LimnoSES.preset_conditions(Clear, Martin) == (0.7, [20.5172, 1.7865, 56.8443])
        @test LimnoSES.preset_conditions(Turbid, Martin) ==
              (2.5, [83.0128, 0.0414705, 6.40048])
        @test LimnoSES.preset_conditions(X1, Martin) == (2.2, [36.730, 2.87725, 26.6798])
        @test LimnoSES.preset_conditions(X2, Martin) == (1.05, [59.0606, 0.819124, 12.0023])
        @test LimnoSES.preset_conditions(X3, Martin) == (1.05, [64.0559, 0.374008, 10.3631])
        @test LimnoSES.preset_conditions(S1, Martin) == (2.0, [79.597, 0.050, 6.928])
        @test LimnoSES.preset_conditions(S2, Martin) == (3.5, [85.436, 0.0373, 6.061])
        @test LimnoSES.preset_conditions(S3, Martin) == (3.5, [20.0, 3.5, 50.0])
        @test LimnoSES.preset_conditions(T1, Martin) == (0.9, [21.647, 2.050, 53.726])
        @test LimnoSES.preset_conditions(T2, Martin) == (2.0, [26.901, 2.809, 41.530])
        @test LimnoSES.preset_conditions(T3, Martin) == (3.0, [20.0, 3.5, 50.0])

        @test sprint(show, "text/plain", lp) ==
              "Parameters for lake dynamics (Martin) model):\nNutrient level: 0.9\nImmigration rate (g⋅m⁻²⋅day⁻¹) for bream: 2.0e-5, pike: 2.0e-5\nGrowth rate (day⁻¹) for bream: 0.0075, Predation rate (day⁻¹) of pike: 0.05\nHalf sturation constants: H₁ 0.5, H₂ 11.0%, H₃ 20.0 g⋅m⁻², H₄ 15.0 g⋅m⁻²\nIntraspecific competition constant (g⋅m⁻²⋅day⁻¹) for bream: 7.5e-5, pike: 0.000275\nPike food conversion efficiency to growth: 0.1, Mortalitiy rate (day⁻¹): 0.00225\nVegetation rates. Growth: 0.007 day⁻¹, mortality: 0.007 day⁻¹, competition: 6.0e-5 m²\n"

        du = [0.0, 0.0, 0.0]
        LimnoSES.lake_dynamics!(du, [20.0, 1.8, 56.8], lp, 0.0)
        @test du == [0.008848571428571449, -9.551327433628197e-5, 0.005225600000000025]
    end
end
