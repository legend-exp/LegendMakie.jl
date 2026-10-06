# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie, CairoMakie
using Test
import Random

import Distributions
import Measurements
import RadiationDetectorSignals
import StatsBase
import TypedTables
import Unitful: @u_str

# Synthetic reports live at top level so that they can also be plotted to files by hand.

rng = Random.MersenneTwister(1)
e_grid_ft = collect((1.0:0.2:4.0)u"µs")
n_ft = length(e_grid_ft)
ok_ft = [i != 3 for i in eachindex(e_grid_ft)]
fwhm_all = (2.5 .+ rand(rng, n_ft))u"keV"
fwhm_all[.!ok_ft] .= NaN * u"keV"
w90_all = 1.9 .* fwhm_all
asym_all = 1.0 .+ 0.1 .* rand(rng, n_ft)
asym_all[.!ok_ft] .= NaN
fct_all = 1e-3 .* rand(rng, n_ft)
fct_all[.!ok_ft] .= NaN
table_ft = TypedTables.Table(ft = e_grid_ft, status = [o ? "ok" : "fit failed" for o in ok_ft],
    fwhm_before = fwhm_all .+ 0.2u"keV", fwhm = fwhm_all, w90 = w90_all, asym = asym_all, tail_fraction = 0.05 .* rand(rng, n_ft),
    tail_scale = rand(rng, n_ft)u"keV", centroid = fill(2614.0u"keV", n_ft), fct = fct_all,
    m_cal_simple = fill(0.01u"keV", n_ft), ctc_converged = trues(n_ft), n_events = fill(5000, n_ft))
# As produced by fit_fwhm_ft: the vectors hold the successful points only, the table all points.
report_ft = (ft = Measurements.measurement(e_grid_ft[5], 0.2u"µs"), min_fwhm = fwhm_all[5], min_objective = w90_all[5],
    objective = :w90, legacy_ft = Measurements.measurement(e_grid_ft[4], 0.2u"µs"), e_grid_ft = e_grid_ft[ok_ft],
    fwhm = fwhm_all[ok_ft], w90 = w90_all[ok_ft], asym = asym_all[ok_ft], fct = fct_all[ok_ft], table = table_ft)

rts = repeat((4.0:0.5:6.0)u"µs", inner = 3)
fts = repeat((1.8:0.2:2.2)u"µs", outer = 5)
n_rtft = length(rts)
fwhm_rtft = (2.4 .+ 0.1 .* rand(rng, n_rtft))u"keV"
fwhm_rtft[2] = NaN * u"keV"
table_rtft = TypedTables.Table(rt = rts, ft = fts, stage = fill(:neighbor, n_rtft),
    step_rt = fill(0.5u"µs", n_rtft), step_ft = fill(0.2u"µs", n_rtft), status = fill("ok", n_rtft),
    fwhm_before = fwhm_rtft .+ 0.2u"keV", fwhm = fwhm_rtft, w90 = 1.9 .* fwhm_rtft, asym = 1.0 .+ 0.1 .* rand(rng, n_rtft),
    tail_fraction = 0.05 .* rand(rng, n_rtft), tail_scale = rand(rng, n_rtft)u"keV", centroid = fill(2614.0u"keV", n_rtft),
    fct = 1e-3 .* rand(rng, n_rtft), m_cal_simple = fill(0.01u"keV", n_rtft), ctc_converged = trues(n_rtft), n_events = fill(5000, n_rtft))
search_path = [(5.0u"µs", 2.0u"µs"), (5.5u"µs", 2.0u"µs"), (5.5u"µs", 2.2u"µs")]
report_rtft = (rt = 5.5u"µs", ft = 2.2u"µs", objective = :w90, table = table_rtft, path = search_path)

function fake_peak_fit(μ, σ, n)
    x = μ .+ σ .* randn(rng, n)
    h = StatsBase.fit(StatsBase.Histogram, x, (μ - 10σ):(σ / 4):(μ + 6σ))
    f_fit = e -> n * Distributions.pdf(Distributions.Normal(μ, σ), e)
    (h = h, f_fit = f_fit, μ = μ * u"keV", σ = σ * u"keV", fwhm = 2.355σ * u"keV", w90 = 3.29σ * u"keV", asym = 1.0)
end
report_peaks = (peaks = [:FEP, :DEP, :SEP],
    legacy = [fake_peak_fit(2614.5, 1.1, 20000), fake_peak_fit(1592.5, 0.9, 3000), fake_peak_fit(2103.5, 1.0, 5000)],
    new = [fake_peak_fit(2614.5, 1.0, 20000), fake_peak_fit(1592.5, 0.85, 3000), fake_peak_fit(2103.5, 0.95, 5000)])

function fake_residuals(n)
    rise_time = (0.3 .+ rand(rng, n))u"µs"
    (residual = randn(rng, n), qdrift = rand(rng, n) .* 100, rise_time = rise_time, aoe = 1.0 .+ 0.02 .* randn(rng, n), slow_mean = -0.2)
end
report_residuals = (legacy = fake_residuals(5000), new = fake_residuals(5000))

aoe_values = vcat(1.0 .+ 0.01 .* randn(rng, 20000), 0.85 .+ 0.05 .* randn(rng, 8000))
report_aoe = (h = StatsBase.normalize(StatsBase.fit(StatsBase.Histogram, aoe_values, 0.7:0.002:1.1), mode = :pdf),
    f_fit = x -> x < 1.0 ? 0.0 : 2 * Distributions.pdf(Distributions.Normal(1.0, 0.01), x),
    μ = 1.0, σ = 0.01, cut_value = 0.98, n_sigma = 2.0, sf = 0.72)

t_wf = range(0u"µs", 100u"µs", length = 1600)
t_flt = range(20u"µs", 100u"µs", length = 1280)
step_wf(t0) = RadiationDetectorSignals.RDWaveform(t_wf, [t < t0 ? 0.0 : 1.0 for t in t_wf] .+ 0.01 .* randn(rng, length(t_wf)))
flt_wf(t0, width) = RadiationDetectorSignals.RDWaveform(t_flt, [abs(t - t0) < width ? 1.0 : 0.0 for t in t_flt])
wvf_classes = [:fast, :fast, :slow, :slow, :high_aoe, :high_aoe]
report_wvfs = (classes = wvf_classes,
    wvfs = [step_wf(48u"µs") for _ in wvf_classes],
    flt_legacy = [flt_wf(55u"µs", 2u"µs") for _ in wvf_classes],
    flt_new = [flt_wf(56u"µs", 3u"µs") for _ in wvf_classes])

@testset "Filter optimization reports" begin
    @testset "ft scan" begin
        @test_nowarn LegendMakie.lplot(report_ft, title = "Test", figsize = (600, 900))
        @test LegendMakie.lplot(report_ft, figsize = (600, 900)) isa Makie.Figure
        @test LegendMakie.lplot(report_ft, legend_position = :none, watermark = false) isa Makie.Figure
        @test LegendMakie.lplot(merge(report_ft, (table = TypedTables.Table(merge(TypedTables.columns(table_ft), (status = fill("ok", n_ft),))),))) isa Makie.Figure
    end
    @testset "ft scan without qdrift" begin
        fwhm_old = Measurements.measurement.(2.5 .+ rand(rng, n_ft), NaN)u"keV"
        min_fwhm, idx = findmin(fwhm_old)
        report_ft_old = (ft = Measurements.measurement(e_grid_ft[idx], 0.2u"µs"), min_fwhm, e_grid_ft, fwhm = fwhm_old)
        @test_nowarn LegendMakie.lplot(report_ft_old, title = "Test")
    end
    @testset "rt/ft landscape" begin
        @test_nowarn LegendMakie.lplot(report_rtft, legacy = (5.0u"µs", 1.8u"µs"), title = "Test", figsize = (700, 550))
        @test LegendMakie.lplot(report_rtft) isa Makie.Figure
        @test LegendMakie.lplot(merge(report_rtft, (objective = :fwhm_asym,))) isa Makie.Figure
        @test LegendMakie.lplot(merge(report_rtft, (objective = :asym,)), legend_position = :none) isa Makie.Figure
        @test_throws ArgumentError LegendMakie.lplot(merge(report_rtft,
            (table = TypedTables.Table(merge(TypedTables.columns(table_rtft), (w90 = fill(NaN * u"keV", n_rtft),))),)))
    end
    @testset "crosscheck peaks" begin
        @test_nowarn LegendMakie.lplot(report_peaks, title = "Test", figsize = (700, 900))
        @test LegendMakie.lplot(report_peaks, yscale = identity) isa Makie.Figure
        @test_throws DimensionMismatch LegendMakie.lplot(merge(report_peaks, (new = report_peaks.new[1:2],)))
    end
    @testset "crosscheck residuals" begin
        @test_nowarn LegendMakie.lplot(report_residuals, title = "Test", figsize = (900, 900))
        @test LegendMakie.lplot(report_residuals, nbins = 30) isa Makie.Figure
        # Events far outside both ranges are clamped into edge bins, none is lost.
        n_res = 1000
        extreme(r) = merge(r, (residual = vcat(r.residual[1:n_res-4], [100.0, -100.0, 100.0, -100.0]),
            qdrift = vcat(r.qdrift[1:n_res-4], [1e6, 1e6, -1e6, -1e6]),
            rise_time = r.rise_time[1:n_res], aoe = r.aoe[1:n_res]))
        extreme_report = (legacy = extreme(fake_residuals(n_res)), new = extreme(fake_residuals(n_res)))
        fig = LegendMakie.lplot(extreme_report)
        heatmaps = [p for ax in fig.content if ax isa Makie.Axis for p in ax.scene.plots if p isa Makie.Heatmap]
        @test length(heatmaps) == 6
        @test all(hm -> sum(hm[3][]) == n_res, heatmaps)
        texts = [string(p.text[]) for ax in fig.content if ax isa Makie.Axis for p in ax.scene.plots if p isa Makie.Text]
        @test any(contains("beyond range"), texts)
        nan_report = (legacy = merge(report_residuals.legacy, (residual = vcat(NaN, report_residuals.legacy.residual[2:end]),)), new = report_residuals.new)
        fig = LegendMakie.lplot(nan_report)
        heatmaps = [p for ax in fig.content if ax isa Makie.Axis for p in ax.scene.plots if p isa Makie.Heatmap]
        @test sum(heatmaps[1][3][]) == length(report_residuals.legacy.residual) - 1
    end
    @testset "A/E selection" begin
        @test_nowarn LegendMakie.lplot(report_aoe, title = "Test")
        @test LegendMakie.lplot(report_aoe, legend_position = :none) isa Makie.Figure
    end
    @testset "example waveforms" begin
        @test_nowarn LegendMakie.lplot(report_wvfs, title = "Test", figsize = (1200, 600))
        @test LegendMakie.lplot(report_wvfs) isa Makie.Figure
        @test LegendMakie.lplot(merge(report_wvfs, (wvfs = RadiationDetectorSignals.ArrayOfRDWaveforms(report_wvfs.wvfs),))) isa Makie.Figure
        @test_throws DimensionMismatch LegendMakie.lplot(merge(report_wvfs, (flt_new = report_wvfs.flt_new[1:5],)))
    end
end
