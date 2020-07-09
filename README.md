# LimnoSES.jl
A limnological social-ecological system hybrid.

Currently under active development and will be prone to major breaking changes.

## An example model run

```julia
using LimnoSES
using Plots

model = initialise(
    experiment = Experiment(identifier = "municipalities", nutrient_series = Dynamic()),
    lake_state = lake_initial_state(X1),
    municipalities = Dict(
        "main" => (
            Governance(
                houseowner_type = Introverted(),
                interventions = [
                                 #WastewaterTreatment(),
                                 #Planting(rate=0.8e-3),
                                 Angling(),
                                 #Trawling(rate=0.9e-3)
                                ]
            ),
            100,
        ),
        "little" => (
            Governance(
                houseowner_type = Enforced(),
                interventions = [WastewaterTreatment(),
                                 Planting(rate=0.5e-3),
                                # Angling(),
                                 Trawling(rate=1.3e-3)
                                ]
            ),
            10,
        ),
        "another" => (
            Governance(
                houseowner_type = Social(),
                interventions = [WastewaterTreatment(),
                                 Planting(rate=0.9e-3,campaign_length=8,threshold=40.0),
                                # Angling(),
                                # Trawling(rate=1.3e-3)
                                ]
            ),
            80,
        ),
    ),
)

_, data = run!(model, agent_step!, model_step!, 60; mdata = [sewage_water])

discrete = model.lake.sol(0:12:365*60)

plot(discrete; labels=["Bream" "Pike" "Vegetation"], xticks=(0:365*5:365*60, 0:5:60))
```
