# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieMakieExt

    import LegendMakie

    import Dates
    import FileIO
    import Format
    import Makie
    import MathTeXEngine
    import StatsBase

    include("recipes/legend_theme.jl")
    include("recipes/recipes.jl")
    include("recipes/lplot.jl")
    include("recipes/lhist.jl")
    include("recipes/watermarks.jl")

    function __init__()

        # Rebind into the main module namespace for end users
        LegendMakie.LegendTheme = LegendTheme

        # maybe just use with_theme() in every plot recipe?
        @debug "Updating Makie theme to LEGEND theme"
        Makie.update_theme!(LegendTheme)

        # add Roboto as possible LaTeXString font
        MathTeXEngine.default_font_families["Roboto"] = MathTeXEngine.FontFamily(
            Dict(
                :regular    => joinpath(dirname(pathof(LegendMakie)), "fonts", "Roboto-Regular.ttf"),
                :italic     => joinpath(dirname(pathof(LegendMakie)), "fonts", "Roboto-Italic.ttf"),
                :bold       => joinpath(dirname(pathof(LegendMakie)), "fonts", "Roboto-Bold.ttf"),
                :bolditalic => joinpath(dirname(pathof(LegendMakie)), "fonts", "Roboto-BoldItalic.ttf"),
                :math       => MathTeXEngine.default_font_families["NewComputerModern"].fonts[:math]
            ), special_chars = MathTeXEngine._symbol_to_new_computer_modern
        )
    end

    function LegendMakie.lplot(args...; figsize = Makie.theme(:size), kwargs...)
        # create new Figure
        fig = Makie.Figure(size = figsize)
        LegendMakie.lplot!(args...; kwargs...)
        fig
    end

    function LegendMakie.lhist(args...; figsize = Makie.theme(:size), kwargs...)
        # create new Figure
        fig = Makie.Figure(size = figsize)
        LegendMakie.lhist!(args...; kwargs...)
        fig
    end

    function LegendMakie.lsavefig(name::AbstractString; kwargs...)
        fig = Makie.current_figure()
        isnothing(fig) && throw(MethodError("No figure to save to file."))
        LegendMakie.lsavefig(fig, name; kwargs...)
    end

    function LegendMakie.lsavefig(fig::Makie.Figure, name::AbstractString; kwargs...)
        FileIO.save(name, fig; kwargs...)
    end


    # ---------------------------------------------------------------------------
    # Generic time-vs-quantity stability heatmap. Covers time-vs-baseline,
    # time-vs-baseline-σ, time-vs-E_cusp, and the pulser-triggered E_cusp subset
    # — construct with new data, no new lplot method needed.
    # ---------------------------------------------------------------------------
    function LegendMakie.lplot(report::LegendMakie.TimeSeriesHeatmapReport)
        finite = isfinite.(report.time) .&& isfinite.(report.y)
        time, y = report.time[finite], report.y[finite]
        isempty(time) && throw(ArgumentError(
            "no finite (time, y) pairs to plot for \"$(report.title)\""
        ))

        yl = something(report.ylims, (minimum(y), maximum(y)))

        xedges = range(minimum(time), maximum(time), length = report.nbins + 1)
        yedges = range(yl[1], yl[2], length = report.nbins + 1)
        h = StatsBase.fit(
            StatsBase.Histogram,
            (time, y),
            (collect(xedges), collect(yedges)),
        )
        xc = 0.5 .* (h.edges[1][1:end-1] .+ h.edges[1][2:end])
        yc = 0.5 .* (h.edges[2][1:end-1] .+ h.edges[2][2:end])
        zlog = log10.(Float64.(h.weights) .+ 1)

        fig = Makie.Figure(size = (900, 600))
        ax = Makie.Axis(
            fig[1, 1],
            xlabel = "Time (s)",
            ylabel = report.ylabel,
            title = report.title,
        )
        hm = Makie.heatmap!(ax, xc, yc, zlog; colormap = :viridis)
        Makie.Colorbar(fig[1, 2], hm, label = "log10(counts + 1)")
        return fig
    end

    # ---------------------------------------------------------------------------
    # 1D log-scale energy histogram (E_cusp distribution).
    # ---------------------------------------------------------------------------
    function LegendMakie.lplot(report::LegendMakie.EnergyHistReport)
        e = filter(isfinite, report.e)
        h1d = StatsBase.fit(StatsBase.Histogram, e, report.binning)
        counts = Float64.(h1d.weights)
        counts[counts .== 0] .= NaN
        edges = h1d.edges[1]

        xstairs, ystairs = Float64[], Float64[]
        for i in eachindex(counts)
            push!(xstairs, edges[i], edges[i+1])
            push!(ystairs, counts[i], counts[i])
        end

        fig = Makie.Figure(size = (900, 400))
        ax = Makie.Axis(
            fig[1, 1],
            xlabel = report.xlabel,
            ylabel = "Counts",
            yscale = log10,
            title = report.title,
        )
        Makie.lines!(ax, xstairs, ystairs; color = :blue, linewidth = 2)
        return fig
    end

    # ---------------------------------------------------------------------------
    # Pulser-based gain stability (ΔE vs time, pulser overlaid with E_cusp).
    # ---------------------------------------------------------------------------

    # Rolling mean/std — private helper for this recipe only.
    function _rollstats(x, N_smooth)
        n, h = length(x), div(N_smooth, 2)
        μ, σ = similar(x), similar(x)
        @inbounds for i in 1:n
            lo, hi = max(1, i - h), min(n, i + h)
            w = @view x[lo:hi]
            μ[i] = StatsBase.mean(w)
            σ[i] = StatsBase.std(w)
        end
        return μ, σ
    end

    function LegendMakie.lplot(report::LegendMakie.GainStabilityReport)
        time, e_cusp, e_puls = report.time, report.e_cusp, report.e_pulser
        e0, ec0 = e_puls[1], e_cusp[1]

        e_pct  = (e_puls .- e0)  ./ e0  .* 100
        ec_pct = (e_cusp .- ec0) ./ ec0 .* 100

        n0 = min(report.n_ref, length(e_pct))
        e_pct  .-= StatsBase.median(e_pct[1:n0])
        ec_pct .-= StatsBase.median(ec_pct[1:n0])

        e_keV  = e_pct  ./ 100 .* report.Qbb
        ec_keV = ec_pct ./ 100 .* report.Qbb

        t0 = StatsBase.median(time[1:n0])
        time_shifted = time .- t0

        e_mean,  e_std  = _rollstats(e_keV, report.n_smooth)
        ec_mean, ec_std = _rollstats(ec_keV, report.n_smooth)

        fig = Makie.Figure(size = (1000, 450), backgroundcolor = :white)
        ax = Makie.Axis(
            fig[1, 1];
            xlabel = "Time (s)",
            ylabel = "ΔE (keV)",
            title = report.title,
            xgridvisible = true,
            ygridvisible = true,
            xgridstyle = :dash,
            ygridstyle = :dash,
        )
        Makie.ylims!(ax, -8, 8)

        # bands first so the mean lines sit on top
        Makie.band!(ax, time_shifted, e_mean .- e_std,  e_mean .+ e_std;  color = (:blue, 0.2))
        Makie.band!(ax, time_shifted, ec_mean .- ec_std, ec_mean .+ ec_std; color = (:red, 0.2))

        Makie.lines!(ax, time_shifted, e_mean;  color = :blue, linewidth = 2, label = "Pulser")
        Makie.lines!(ax, time_shifted, ec_mean; color = :red,  linewidth = 2, label = "E_cusp")

        Makie.axislegend(ax; position = :rt)
        return fig
    end
end