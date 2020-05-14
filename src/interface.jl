module Interface
using MakieLayout, AbstractPlotting, StatsMakie, DataFrames
export interface

struct InterfaceData
    daily::DataFrame
    yearly::DataFrame
    individual::DataFrame
end

mutable struct DailyObservable
    bream::Observable{Vector{Float64}}
    pike::Observable{Vector{Float64}}
    sewage::Observable{Vector{Float64}}
    vegetation::Observable{Vector{Float64}}
end

"Requires the daily dataframe"
function DailyObservable(daily::DataFrame)
    DailyObservable(daily.bream, daily.pike, daily.sewage_water, daily.vegetation)
end

mutable struct YearlyObservable
    nutrients::Observable{Vector{Float64}}
    plp::Observable{Vector{Float64}}
    info::Observable{Vector{Integer}}
    oss::Observable{Vector{Integer}}
    upeff::Observable{Vector{Float64}}
    compliance::Observable{Vector{Float64}}
end

"Expects yearly data, agent, agg_agent order"
function YearlyObservable(data::InterfaceData, agent_count::Integer)
    info, oss = refactor_agg_data(data.yearly[end, :], agent_count)
    YearlyObservable(
        data.yearly.nutrients,
        data.yearly.pike_loss_perception,
        info,
        oss,
        data.yearly.upgrade_efficiency,
        data.individual.compliance,
    )
end

# TODO: We can probably call this outside of update and send it into the observable struct instead of the dataframe and count
function refactor_agg_data(aggyear::DataFrameRow, agent_count::Integer)
    current_info = aggyear.count_information
    info = [agent_count - current_info, current_info]
    current_oss = aggyear.count_oss
    oss = [agent_count - current_oss, current_oss]
    info, oss
end

"Requires the daily dataframe"
function updateplots!(day::DailyObservable, daily::DataFrame)
    day.bream[] = daily.bream
    day.pike[] = daily.pike
    day.sewage[] = daily.sewage_water
    day.vegetation[] = daily.vegetation
end

"Expects yearly and individual dataframes"
function updateplots!(
    year::YearlyObservable,
    yearly::DataFrame,
    individual::DataFrame,
    aggidx::Integer,
    agent_count::Integer,
)
    info, oss = refactor_agg_data(yearly[aggidx, :], agent_count)
    year.nutrients[] = yearly.nutrients
    year.plp[] = yearly.pike_loss_perception
    year.info[] = info
    year.oss[] = oss
    year.upeff[] = yearly.upgrade_efficiency
    year.compliance[] = individual.compliance
end

function interface(data::InterfaceData, agent_count::Integer, simlength::Integer)
    day = DailyObservable(data.daily)
    year = YearlyObservable(data, agent_count)

    scene, layout = layoutscene(resolution = (1920, 1080), backgroundcolor = :white)
    dax =
        layout[1:3, 1] = [
            LAxis(scene, title = title) for title in ["Fish Stock", "Sewage", "Vegetation"]
        ]
    linkxaxes!((a for a in dax)...)
    hidexdecorations!(dax[1], grid = false)
    hidexdecorations!(dax[2], grid = false)

    resetbutton = LButton(
        scene,
        label = "reset",
        buttoncolor = RGBf0(0.8, 0.8, 0.8),
        height = 40,
        width = 80,
    )
    runbutton = LButton(
        scene,
        label = Observable("run"),
        buttoncolor = Observable(RGBf0(0.8, 0.8, 0.8)),
        buttoncolor_hover = Observable(RGBf0(0.7, 0.7, 0.9)),
        buttoncolor_active = Observable(RGBf0(0.6, 0.6, 1.0)),
        labelcolor = Observable((RGBf0(0, 0, 0))),
        labelcolor_active = Observable((RGBf0(1, 1, 1))),
        height = 40,
        width = 70,
    )
    backday = LButton(
        scene,
        label = "‹",
        buttoncolor = RGBf0(0.8, 0.8, 0.8),
        height = 40,
        width = 40,
    )
    backyear = LButton(
        scene,
        label = "«",
        buttoncolor = RGBf0(0.8, 0.8, 0.8),
        height = 40,
        width = 40,
    )
    forwardday = LButton(
        scene,
        label = "›",
        buttoncolor = RGBf0(0.8, 0.8, 0.8),
        height = 40,
        width = 40,
    )
    forwardyear = LButton(
        scene,
        label = "»",
        buttoncolor = RGBf0(0.8, 0.8, 0.8),
        height = 40,
        width = 40,
    )
    nslider = LSlider(scene, range = 0:simlength, startvalue = simlength)
    slabel = lift(
        a -> string("year: ", floor(Integer, a / 365), ", day: ", a % 365),
        nslider.value,
    )
    controls =
        [resetbutton runbutton LText(scene, slabel) backyear backday nslider forwardday forwardyear]

    layout[4, 1:2] = grid!(controls, tellwidth = false, tellheight = true)

    yax =
        layout[1:3, 2] = [
            LAxis(scene, title = title)
            for title in ["Nutrients", "Pike Loss Perception", "Upgrade Efficiency"]
        ]
    linkxaxes!(yax[1], yax[2], yax[3])
    hidexdecorations!(yax[1], grid = false)
    hidexdecorations!(yax[2], grid = false)

    aax =
        layout[1:3, 3] = [
            LAxis(scene, title = title)
            for title in [
                "Informed Households",
                "Upgraded Households",
                "Willingness to Upgrade",
            ]
        ]

    lp = lines!(dax[1], day.pike, color = :red)
    lb = lines!(dax[1], day.bream, color = :blue)
    layout[1, 1] = LLegend(
        scene,
        [lp, lb],
        ["Pike", "Bream"],
        tellwidth = false,
        halign = :right,
        valign = :center,
    )
    lines!(dax[2], day.sewage)
    lines!(dax[3], day.vegetation)

    lines!(yax[1], year.nutrients)
    lines!(yax[2], year.plp)
    lines!(yax[3], year.upeff)
    barplot!(aax[1], year.info)
    barplot!(aax[2], year.oss)
    plot!(aax[3], histogram(nbins = 10), year.compliance)

#    color        :black
#  colormap     :viridis
#  colorrange   AbstractPlotting.Automatic()
#  fillto       0.0
#  marker       GeometryBasics.HyperRectangle
#  strokecolor  :white
#  strokewidth  0
#  width        AbstractPlotting.Automatic()
    # Only useful until MakieLayout has a toggle button
    on(runbutton.clicks) do n
        t = runbutton.label[] == "run" ? "stop" : "run"
        runbutton.label[] = t
        for (s1, s2) in
            ((:buttoncolor, :buttoncolor_active), (:labelcolor, :labelcolor_active))
            getproperty(runbutton, s1)[], getproperty(runbutton, s2)[] =
                getproperty(runbutton, s2)[], getproperty(runbutton, s1)[]
        end
        runbutton.labelcolor_hover[] = runbutton.labelcolor[]
    end

    on(nslider.value) do slide
        # Update display so that plot values are only [0, slide]
        # Indexes are offset by one since row 0 is the initial data
        idxs = 1:(slide + 1)
        updateplots!(day, data.daily[idxs, :])
        current_year = floor(Integer, slide / 365)+1
        yidxs = 1:current_year
        updateplots!(
            year,
            data.yearly[yidxs, :],
            data.individual[yidxs, :],
            current_year,
            agent_count,
        )
        #Axes are linked so this updates everything
        xlims!(dax[1], MakieLayout.expandlimits((0, slide), 0.05, 0.05))
        xlims!(yax[1], MakieLayout.expandlimits((0, current_year + 1), 0.05, 0.05))
    end

    on(backday.clicks) do click
        set_close_to!(nslider, nslider.value[] - 1)
    end

    on(backyear.clicks) do click
        set_close_to!(nslider, nslider.value[] - 365)
    end

    on(forwardday.clicks) do click
        set_close_to!(nslider, nslider.value[] + 1)
    end

    on(forwardyear.clicks) do click
        set_close_to!(nslider, nslider.value[] + 365)
    end

    return scene
end
end

