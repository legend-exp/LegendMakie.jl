# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

# Plots of the result of LegendDSP's `dsp_dplms_optimization`, one `lplot!` method per view,
# dispatching on the field names of a report built from that result. Times are in µs relative
# to the alignment point (`t50`).

# sequential palette of the LEGEND colors for series ordered by ff or drift time
dplms_palette(n) = Makie.cgrad(Makie.to_color.([LegendMakie.DeepCove, LegendMakie.PPCPurple, LegendMakie.BEGeOrange]), n; categorical = true)

# curve label of grid point g: the grid fields that vary over the grid, ff in µs (Δt in µs)
dplms_grid_label(grid, g, Δt) = join([k == :ff ? "ff = $(round(grid[g].ff * Δt; digits = 2)) µs" : "$k = $(grid[g][k])"
    for k in keys(grid[g]) if !allequal(w[k] for w in grid)], ", ")

# superpulse sample nearest the median alignment time, in µs
dplms_t0(superpulse, t50) = (t = Unitful.ustrip.(u"µs", superpulse.time); t[argmin(abs.(t .- Unitful.ustrip(u"µs", StatsBase.median(t50))))])

# superpulse, window reference and per-drift-bin references
function LegendMakie.lplot!(
        report::NamedTuple{(:superpulse, :ref, :ref_bins, :t50, :t_pickoff, :n_pre, :n_post)};
        plateau_length::Integer = 20, title::AbstractString = "", titlesize = 18, titlegap = 0,
        xlims = nothing, legend_position = :rb, bin_legend_position = :lt, row::Int = 1, col::Int = 1,
        watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )
    fig = Makie.current_figure()
    Δt = Unitful.ustrip(u"µs", step(report.superpulse.time))
    t_sp = Unitful.ustrip.(u"µs", report.superpulse.time)
    t0 = dplms_t0(report.superpulse, report.t50)
    tp = Unitful.ustrip(u"µs", report.t_pickoff)
    trel = (-report.n_pre:report.n_post) .* Δt
    nb = size(report.ref_bins, 2)
    colors = dplms_palette(nb)
    g = Makie.GridLayout(fig[row, col])

    ax = Makie.Axis(g[1, 1:2]; xlabel = "Time relative to t50 (µs)", ylabel = "Superpulse (unit plateau)", limits = (xlims, nothing))
    Makie.lines!(ax, t_sp .- t0, report.superpulse.signal; color = LegendMakie.ICPCBlue, linewidth = 2)
    Makie.vlines!(ax, -report.n_pre * Δt; color = :gray, linestyle = :dash, linewidth = 2, label = "Window start")
    Makie.vlines!(ax, 0.0; color = LegendMakie.PPCPurple, linestyle = :dash, linewidth = 2, label = "t50")
    Makie.vlines!(ax, tp; color = LegendMakie.BEGeOrange, linestyle = :dash, linewidth = 2, label = "Pick-off")
    Makie.vspan!(ax, tp - (plateau_length - 1) * Δt, tp; color = (LegendMakie.CoaxGreen, 0.3), label = "Reference plateau")
    Makie.axislegend(ax, position = legend_position)

    axl = Makie.Axis(g[2, 1]; xlabel = "Time relative to t50 (µs)", ylabel = "Reference (unit plateau)")
    Makie.lines!(axl, trel, report.ref; color = LegendMakie.ICPCBlue, linewidth = 5, label = "Mean")
    axd = Makie.Axis(g[2, 2]; xlabel = "Time relative to t50 (µs)", ylabel = "Bin reference − mean")
    for b in 1:nb
        Makie.lines!(axl, trel, report.ref_bins[:, b]; color = colors[b], linewidth = 2, label = "$b")
        Makie.lines!(axd, trel, report.ref_bins[:, b] .- report.ref; color = colors[b], linewidth = 2)
    end
    for a in (axl, axd)
        Makie.vlines!(a, [0.0, tp]; color = [LegendMakie.PPCPurple, LegendMakie.BEGeOrange], linestyle = :dash, linewidth = 2)
        Makie.vspan!(a, tp - (plateau_length - 1) * Δt, tp; color = (LegendMakie.CoaxGreen, 0.3))
    end
    Makie.axislegend(axl, "Drift-time bin\n(short to long)", position = bin_legend_position)
    Makie.linkxaxes!(axl, axd)

    !isempty(title) && Makie.Label(g[1, :, Makie.Top()], title, padding = (0, 0, titlegap, 0), fontsize = titlesize, font = :bold)
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    fig
end

# time-ordered filter weights against the trapezoid read out at t50 + rt + ft/2
function LegendMakie.lplot!(
        report::NamedTuple{(:coeffs, :grid, :superpulse, :t_pickoff, :n_pre, :n_post)};
        idxs = eachindex(report.grid), rt = 5.0u"µs", ft = 2.5u"µs",
        title::AbstractString = "", titlesize = 18, xlims = nothing, ylims = nothing, legend_position = :lt,
        row::Int = 1, col::Int = 1, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )
    fig = Makie.current_figure()
    Δt = step(report.superpulse.time)
    trel = (-report.n_pre:report.n_post) .* Unitful.ustrip(u"µs", Δt)
    ax = Makie.Axis(fig[row, col]; title, titlesize, limits = (xlims, ylims), titlefont = :bold,
        xlabel = "Time relative to t50 (µs)", ylabel = "Filter weight (per unit response)")
    colors = dplms_palette(length(idxs))
    for (c, g) in zip(colors, idxs)
        Makie.lines!(ax, trel, reverse(report.coeffs[g]); color = c, linewidth = 2, label = dplms_grid_label(report.grid, g, Unitful.ustrip(u"µs", Δt)))
    end
    # trapezoid weights centered on t50: -1/L on the L samples before the flat top, 0 on the F flat-top samples, +1/L on the L samples after
    L, F = round(Int, Unitful.ustrip(Unitful.NoUnits, rt / Δt)), round(Int, Unitful.ustrip(Unitful.NoUnits, ft / Δt))
    k = (-(L + F ÷ 2)):(L + F - F ÷ 2 - 1)
    (first(k) >= -report.n_pre && last(k) <= report.n_post) || throw(ArgumentError("trapezoid of $(length(k)) samples around t50 does not fit the window from -$(report.n_pre) to $(report.n_post) samples"))
    Makie.lines!(ax, k .* Unitful.ustrip(u"µs", Δt), [fill(-1 / L, L); zeros(F); fill(1 / L, L)]; color = :black, linestyle = :dash, linewidth = 2, label = "Trapezoid $rt + $ft")
    Makie.vlines!(ax, [0.0, Unitful.ustrip(u"µs", report.t_pickoff)]; color = [LegendMakie.PPCPurple, LegendMakie.BEGeOrange], linestyle = :dot, linewidth = 2)
    legend_position == :none || Makie.axislegend(ax, position = legend_position)
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    fig
end

# superpulse and filter output (the output at time t belongs to the window ending at t)
function LegendMakie.lplot!(
        report::NamedTuple{(:superpulse, :response, :grid, :t50, :t_pickoff, :n_pre, :n_post)};
        idxs = eachindex(report.grid), title::AbstractString = "", titlesize = 18, titlegap = 0,
        xlims = nothing, ylims = nothing, zoom_xlims = nothing, zoom_ylims = (0.99, 1.01), legend_position = :lt,
        row::Int = 1, col::Int = 1, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )
    fig = Makie.current_figure()
    Δt = Unitful.ustrip(u"µs", step(report.superpulse.time))
    t_sp = Unitful.ustrip.(u"µs", report.superpulse.time)
    t0 = dplms_t0(report.superpulse, report.t50)
    tp = Unitful.ustrip(u"µs", report.t_pickoff)
    xlims = something(xlims, (-report.n_pre * Δt - 1, tp + 4))
    zoom_xlims = something(zoom_xlims, (tp - 1, tp + 1))
    g = Makie.GridLayout(fig[row, col])
    axs = [Makie.Axis(g[1, i]; xlabel = "Time relative to t50 (µs)", ylabel = "Amplitude (unit plateau)", limits = (lim, i == 1 ? ylims : zoom_ylims)) for (i, lim) in enumerate((xlims, zoom_xlims))]
    colors = dplms_palette(length(idxs))
    for ax in axs
        Makie.lines!(ax, t_sp .- t0, report.superpulse.signal; color = LegendMakie.DiamondGrey, linewidth = 4, label = "Superpulse")
        for (c, gi) in zip(colors, idxs)
            Makie.lines!(ax, Unitful.ustrip.(u"µs", report.response[gi].time) .- t0, report.response[gi].signal; color = c, linewidth = 2, label = dplms_grid_label(report.grid, gi, Δt))
        end
        Makie.vlines!(ax, tp; color = LegendMakie.BEGeOrange, linestyle = :dash, linewidth = 2, label = "Pick-off")
    end
    legend_position == :none || Makie.axislegend(axs[1], position = legend_position)
    # a row of its own: the top tick label of the zoom axis reaches above the axes
    !isempty(title) && Makie.Label(g[0, :], title, padding = (0, 0, titlegap, 0), fontsize = titlesize, font = :bold)
    Makie.current_axis!(axs[2])
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    fig
end

# noise, flat-top and reference matrices and the noise autocorrelation
function LegendMakie.lplot!(
        report::NamedTuple{(:noise, :flattops, :ref, :superpulse, :n_pre, :n_post)};
        ff::Integer = maximum(keys(report.flattops)), title::AbstractString = "", titlesize = 18, titlegap = 0,
        row::Int = 1, col::Int = 1, watermark::Bool = true, final::Bool = !isempty(title), kwargs...
    )
    fig = Makie.current_figure()
    Δt = Unitful.ustrip(u"µs", step(report.superpulse.time))
    s = (-report.n_pre:report.n_post) .* Δt
    g = Makie.GridLayout(fig[row, col])
    sequential = Makie.cgrad(Makie.to_color.([LegendMakie.DeepCove, LegendMakie.PPCPurple, LegendMakie.BEGeOrange]))
    diverging = Makie.cgrad(Makie.to_color.([LegendMakie.ICPCBlue, :white, LegendMakie.BEGeOrange]))
    # color ranges are clipped at a quantile of |entries| so that the noise diagonal and the flat-top core do not wash out the rest
    mats = [("Noise (clipped)", report.noise, diverging, 0.95), ("Flat-top, ff = $(round(ff * Δt; digits = 2)) µs (clipped)", report.flattops[ff], sequential, 0.99), ("Reference ⊗ reference", report.ref * report.ref', sequential, 1.0)]
    for (i, (mtitle, M, cmap, q)) in enumerate(mats)
        gi = Makie.GridLayout(g[fld1(i, 2), mod1(i, 2)])
        ax = Makie.Axis(gi[1, 1]; xlabel = "Time relative to t50 (µs)", ylabel = "Time relative to t50 (µs)", title = mtitle, aspect = 1)
        c = StatsBase.quantile(vec(abs.(M)), q)
        hm = Makie.heatmap!(ax, s, s, M; colormap = cmap, colorrange = i == 1 ? (-c, c) : (minimum(M), min(maximum(M), c)))
        Makie.Colorbar(gi[1, 2], hm)
    end
    n = size(report.noise, 1)
    acf = [StatsBase.mean(report.noise[i, i + k] for i in 1:(n - k)) for k in 0:(n - 1)]
    ax = Makie.Axis(g[2, 2]; xlabel = "Lag (µs)", ylabel = "Noise autocorrelation")
    Makie.hlines!(ax, 0.0; color = :gray, linestyle = :dash, linewidth = 2)
    Makie.lines!(ax, (0:(n - 1)) .* Δt, acf ./ first(acf); color = LegendMakie.ICPCBlue, linewidth = 2)
    # a row of its own: the matrix axes carry titles
    !isempty(title) && Makie.Label(g[0, :], title, padding = (0, 0, titlegap, 0), fontsize = titlesize, font = :bold)
    Makie.current_axis!(ax)
    watermark && LegendMakie.add_watermarks!(; final, kwargs...)
    fig
end
