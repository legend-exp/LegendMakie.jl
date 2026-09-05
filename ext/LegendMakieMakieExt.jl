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

    function LegendMakie.lgainstability(args...; figsize = (1000, 450), kwargs...)
        fig = Makie.Figure(size = figsize, backgroundcolor = :white)
        LegendMakie.lgainstability!(args...; kwargs...)
        fig
    end

    function LegendMakie.lsavefig(name::AbstractString; kwargs...)
        fig = Makie.current_figure()
        isnothing(fig) && throw(MethodError("No figure to save to file."))
        LegendMakie.lsavefig(fig, name; kwargs...)
    end

    # Makie keeps every figure reachable through listeners on the global theme, so a long
    # session leaks ~90 MB per saved figure; empty!(fig) after saving disconnects them.
    function LegendMakie.lsavefig(fig::Makie.Figure, name::AbstractString; cleanup::Bool = true, kwargs...)
        ret = FileIO.save(name, fig; kwargs...)
        cleanup && Base.empty!(fig)
        return ret
    end

    # Rolling mean/std for the gain-stability plot.
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

    function LegendMakie.lgainstability!(
        time::AbstractVector{<:Real},
        energy::AbstractVector{<:Real},
        pulser_energy::AbstractVector{<:Real};
        Qbb::Real = 2039.0,
        n_ref::Integer = 500,
        n_smooth::Integer = 201,
        title::AbstractString = "",
        xlabel::AbstractString = "Time (s)",
        ylabel::AbstractString = "ΔE (keV)",
        ylims = (-8, 8),
        energy_label::AbstractString = "E_cusp",
        pulser_label::AbstractString = "Pulser",
        watermark::Bool = true,
        position::String = "outer top",
        final::Bool = !isempty(title),
        kwargs...,
    )
        length(time) == length(energy) == length(pulser_energy) ||
            throw(DimensionMismatch("time, energy, and pulser_energy must have the same length"))
        n_ref > 0 || throw(ArgumentError("n_ref must be positive"))
        n_smooth > 0 || throw(ArgumentError("n_smooth must be positive"))

        finite = isfinite.(time) .&& isfinite.(energy) .&& isfinite.(pulser_energy)
        any(finite) || throw(ArgumentError("no finite gain-stability samples to plot"))
        time_finite = float.(time[finite])
        energy_finite = float.(energy[finite])
        pulser_finite = float.(pulser_energy[finite])
        e0, ec0 = pulser_finite[1], energy_finite[1]
        (!iszero(e0) && !iszero(ec0)) ||
            throw(ArgumentError("reference energies must be nonzero"))

        e_pct  = (pulser_finite .- e0) ./ e0 .* 100
        ec_pct = (energy_finite .- ec0) ./ ec0 .* 100

        n0 = min(n_ref, length(e_pct))
        e_pct  .-= StatsBase.median(e_pct[1:n0])
        ec_pct .-= StatsBase.median(ec_pct[1:n0])

        e_keV  = e_pct  ./ 100 .* Qbb
        ec_keV = ec_pct ./ 100 .* Qbb

        t0 = StatsBase.median(time_finite[1:n0])
        time_shifted = time_finite .- t0

        e_mean,  e_std  = _rollstats(e_keV, n_smooth)
        ec_mean, ec_std = _rollstats(ec_keV, n_smooth)

        fig = Makie.current_figure()
        ax = Makie.Axis(
            fig[1, 1];
            xlabel,
            ylabel,
            title,
            xgridvisible = true,
            ygridvisible = true,
            xgridstyle = :dash,
            ygridstyle = :dash,
        )
        Makie.ylims!(ax, ylims...)

        # bands first so the mean lines sit on top
        Makie.band!(ax, time_shifted, e_mean .- e_std,  e_mean .+ e_std;  color = (:blue, 0.2))
        Makie.band!(ax, time_shifted, ec_mean .- ec_std, ec_mean .+ ec_std; color = (:red, 0.2))

        Makie.lines!(ax, time_shifted, e_mean;  color = :blue, linewidth = 2, label = pulser_label)
        Makie.lines!(ax, time_shifted, ec_mean; color = :red,  linewidth = 2, label = energy_label)

        Makie.axislegend(ax; position = :rt)
        Makie.current_axis!(ax)
        watermark && LegendMakie.add_watermarks!(; position, final, kwargs...)
        return fig
    end
end