struct TimeSeriesHeatmapReport
    time::Vector{Float64}
    y::Vector{Float64}
    ylabel::String
    title::String
    ylims::Union{Nothing, Tuple{Float64,Float64}}
    nbins::Int
end

TimeSeriesHeatmapReport(time, y; ylabel, title, ylims = nothing, nbins = 600) =
    TimeSeriesHeatmapReport(
        collect(float.(time)),
        collect(float.(y)),
        ylabel,
        title,
        ylims,
        nbins
    )


struct EnergyHistReport
    e::Vector{Float64}
    xlabel::String
    title::String
    binning::AbstractRange
end

EnergyHistReport(e; xlabel, title, binning = 0:1000:6e5) =
    EnergyHistReport(collect(float.(e)), xlabel, title, binning)


struct GainStabilityReport
    time::Vector{Float64}
    e_cusp::Vector{Float64}
    e_pulser::Vector{Float64}
    Qbb::Float64
    n_ref::Int
    n_smooth::Int
    title::String
end

GainStabilityReport(
    time, e_cusp, e_pulser;
    Qbb = 2039.0,
    n_ref = 500,
    n_smooth = 201,
    title
) =
    GainStabilityReport(
        collect(float.(time)),
        collect(float.(e_cusp)),
        collect(float.(e_pulser)),
        Qbb,
        n_ref,
        n_smooth,
        title
    )