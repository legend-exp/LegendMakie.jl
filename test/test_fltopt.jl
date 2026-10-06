# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie, CairoMakie
using Test

import Distributions
import LegendSpecFits
import Measurements
import RadiationDetectorSignals
import StatsBase
import TypedTables
import Unitful: @u_str

# Synthetic reports live at top level so that they can also be plotted to files by hand.

e_grid_ft = collect((1.0:0.2:4.0)u"µs")
n_ft = length(e_grid_ft)
fwhm = (2.5 .+ rand(n_ft))u"keV"
fwhm[3] = NaN * u"keV"
w90 = 1.9 .* fwhm
asym = 1.0 .+ 0.1 .* rand(n_ft)
fct = 1e-3 .* rand(n_ft)
table_ft = TypedTables.Table(ft = e_grid_ft, status = [i == 3 ? "fit failed" : "ok" for i in eachindex(e_grid_ft)],
    fwhm_before = fwhm .+ 0.2u"keV", fwhm = fwhm, w90 = w90, asym = asym, tail_fraction = 0.05 .* rand(n_ft),
    tail_scale = rand(n_ft)u"keV", centroid = fill(2614.0u"keV", n_ft), fct = fct,
    m_cal_simple = fill(0.01u"keV", n_ft), ctc_converged = trues(n_ft), n_events = fill(5000, n_ft))
report_ft = (ft = Measurements.measurement(e_grid_ft[5], 0.2u"µs"), min_fwhm = fwhm[5], min_objective = w90[5],
    objective = :w90, legacy_ft = e_grid_ft[4], e_grid_ft = e_grid_ft, fwhm = fwhm, w90 = w90, asym = asym, fct = fct, table = table_ft)

rts = repeat((4.0:0.5:6.0)u"µs", inner = 3)
fts = repeat((1.8:0.2:2.2)u"µs", outer = 5)
n_rtft = length(rts)
fwhm_rtft = (2.4 .+ 0.1 .* rand(n_rtft))u"keV"
fwhm_rtft[2] = NaN * u"keV"
table_rtft = TypedTables.Table(rt = rts, ft = fts, stage = fill(:neighbor, n_rtft),
    step_rt = fill(0.5u"µs", n_rtft), step_ft = fill(0.2u"µs", n_rtft), status = fill("ok", n_rtft),
    fwhm_before = fwhm_rtft .+ 0.2u"keV", fwhm = fwhm_rtft, w90 = 1.9 .* fwhm_rtft, asym = 1.0 .+ 0.1 .* rand(n_rtft),
    tail_fraction = 0.05 .* rand(n_rtft), tail_scale = rand(n_rtft)u"keV", centroid = fill(2614.0u"keV", n_rtft),
    fct = 1e-3 .* rand(n_rtft), m_cal_simple = fill(0.01u"keV", n_rtft), ctc_converged = trues(n_rtft), n_events = fill(5000, n_rtft))
search_path = [(5.0u"µs", 2.0u"µs"), (5.5u"µs", 2.0u"µs"), (5.5u"µs", 2.2u"µs")]
report_rtft = (rt = 5.5u"µs", ft = 2.2u"µs", objective = :w90, table = table_rtft, path = search_path)

@testset "Filter optimization reports" begin
    @testset "ft scan" begin
        @test_nowarn LegendMakie.lplot(report_ft, title = "Test", figsize = (600, 900))
        @test LegendMakie.lplot(report_ft, figsize = (600, 900)) isa Makie.Figure
        @test LegendMakie.lplot(report_ft, legend_position = :none, watermark = false) isa Makie.Figure
    end
    @testset "rt/ft landscape" begin
        @test_nowarn LegendMakie.lplot(report_rtft, legacy = (5.0u"µs", 1.8u"µs"), title = "Test", figsize = (700, 550))
        @test LegendMakie.lplot(report_rtft) isa Makie.Figure
        @test LegendMakie.lplot(merge(report_rtft, (objective = :fwhm_asym,))) isa Makie.Figure
        @test LegendMakie.lplot(merge(report_rtft, (objective = :asym,)), legend_position = :none) isa Makie.Figure
        @test_throws ArgumentError LegendMakie.lplot(merge(report_rtft,
            (table = TypedTables.Table(merge(TypedTables.columns(table_rtft), (w90 = fill(NaN * u"keV", n_rtft),))),)))
    end
end
