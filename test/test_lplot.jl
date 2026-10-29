# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie, CairoMakie

import LegendSpecFits
import LegendDataManagement
import LegendHDF5IO
import LegendTestData

include("testing_utils.jl")

import Dates
import Distributions
import Random
import Measurements
import PropDicts, JSON
import RadiationDetectorSignals
import StatsBase
import TypedTables
import Unitful: @u_str

using Test

@testset "lsavefig" begin
    # Empty figures cannot be plotted
    @test_throws MethodError lsavefig("empty.pdf")
    @test !isfile("empty.pdf")
    for fileformat in ("pdf", "png", "svg")
        @testset "Fileformat: $(fileformat)" begin 
            fn = "test.$(fileformat)"
            isfile(fn) && rm(file)
            Makie.scatter(rand(10), rand(10))
            @test_nowarn lsavefig(fn)
            @test isfile(fn)
            rm(fn)
        end
    end
    @testset "cleanup after saving" begin
        # saving empties the figure by default (breaks the global-theme references that
        # otherwise keep every saved figure alive); cleanup = false keeps it intact
        fig = Makie.Figure()
        Makie.Axis(fig[1, 1]); Makie.Label(fig[2, 1], "keep")
        @test length(fig.content) == 2
        lsavefig(fig, "cleanup.png")
        @test isempty(fig.content)
        rm("cleanup.png")
        fig2 = Makie.Figure()
        Makie.Axis(fig2[1, 1])
        lsavefig(fig2, "nocleanup.png"; cleanup = false)
        @test length(fig2.content) == 1
        rm("nocleanup.png")
    end
end

@testset "lplot" begin

    @testset "Test default plot recipe using LegendMakie theme" begin
        @test_logs (:info,) LegendMakie.lplot(rand(10))
    end

    @testset "Test watermarks" begin
        # test default watermark
        @test_nowarn LegendMakie.lplot(StatsBase.fit(StatsBase.Histogram, randn(10000)), label = "Test")
        @test_nowarn LegendMakie.add_watermarks!()

        # test alternative watermark
        fig = Figure()
        ax = Axis(fig[1,2])
        @test_nowarn LegendMakie.residualplot!(ax, (x = 1:10, residuals_norm = randn(10)))
        @test_nowarn LegendMakie.add_watermarks!(legend_logo = true, position = "outer top", preliminary = false)
        @test_throws ArgumentError LegendMakie.add_watermarks!(position = "Test")
    end

    @testset "Stability plots" begin
        @testset "Time-series heatmap" begin
            time = collect(0.0:9.0)
            values = collect(0.1:0.1:1.0)

            @test_nowarn lhist(time, values; bins = 10, ylabel = "Baseline (ADC)", title = "Baseline stability")
            @test_nowarn lhist(time, values; bins = (10, 20), ylabel = "Baseline σ (ADC)", title = "Baseline σ stability", ylims = (0.0, 1.2))
            @test_throws DimensionMismatch lhist([1.0], [1.0, 2.0])
        end

        @testset "Energy histogram" begin
            energy = [100.0, 150.0, 900.0, 1_100.0]
            @test_nowarn lhist(energy; xlabel = "E_cusp (ADC)", title = "E_cusp distribution", bins = 0.0:250.0:1_500.0, yscale = Makie.log10)
            @test_nowarn lhist(energy; xlabel = "E_cusp (ADC)", title = "E_cusp distribution", bins = 10.0 .^ range(1, 4, length=31), xscale = Makie.log10, yscale = Makie.log10)
        end
    end

    @testset "Test LegendSpecFits reports" begin
        @testset "Singlefits" begin
            result, report = LegendSpecFits.fit_single_trunc_gauss(randn(10000), (low = -4.0, high = 4.0, max = NaN))
            @test_nowarn lplot(report, xlabel = "x")

            result, report = LegendSpecFits.fit_single_trunc_gauss(randn(10000), uncertainty = false)
            @test_nowarn lplot(report, xlabel = "Test")

            result, report = LegendSpecFits.get_centered_gaussian_window_cut(randn(10000), -10.0, 10.0, 1.0; n_bins = -1)
            @test_nowarn lplot(report, xlabel = "Test")
        end

        @testset "QC" begin
            t = TypedTables.Table(x1 = randn(1000000), x2 = randn(1000000))
            config = PropDicts.PropDict(
                :x1 => PropDicts.PropDict(:min => -10.0, :max => 10.0, :sigma => 2.0,
                    :kwargs => PropDicts.PropDict(:relative_cut => 0.01, :n_bins => -1, :fixed_center => false, :left => false)
                ),
                :x2 => PropDicts.PropDict(:min => -10.0, :max => 10.0, :sigma => 2.0,
                    :kwargs => PropDicts.PropDict(:relative_cut => 0.01, :n_bins => -1, :fixed_center => false, :left => true)
                ))
            
            result, report = LegendSpecFits.qc_window_cut(t, config)
            @test_nowarn lplot(report, figsize = (600,900), title = "Test")
        end

        @testset "Filter optimization" begin
            # Did not manage to call the function, so generate fake report
            enc_grid_rt = (1.5:0.5:16.0)u"μs"
            enc = Measurements.measurement.(rand(length(enc_grid_rt)) .+ 1.0, rand(length(enc_grid_rt)))
            min_enc, idx = findmin(enc)
            rt = Measurements.measurement(enc_grid_rt[idx], step(enc_grid_rt))
            report_rt = (; rt, min_enc, enc_grid_rt, enc)
            @testset "ENC vs. Rise Time" begin
                @test_nowarn LegendMakie.lplot(report_rt, title = "Test")
            end
            a_grid_wl_sg = (30:32.:350)u"ns"
            sfs = Measurements.measurement.(rand(length(a_grid_wl_sg)), NaN) .* 100u"percent" 
            min_sf, idx = findmin(sfs)
            wl = Measurements.measurement(a_grid_wl_sg[idx], step(a_grid_wl_sg))
            report_wl = (; wl, min_sf, a_grid_wl_sg, sfs)
            @testset "A/E: SEP SF vs. Window length" begin
                @test_nowarn LegendMakie.lplot(report_wl, title = "Test")
            end
            a_grid_wl_sg = (1.5:0.5:16.0)u"μs"
            obj = Measurements.measurement.(rand(length(a_grid_wl_sg)), rand(length(a_grid_wl_sg)))
            min_obj, idx = findmin(obj)
            wl = Measurements.measurement(a_grid_wl_sg[idx], step(a_grid_wl_sg))
            report_obj = (; wl, min_obj, gain = missing, res_1pe = missing, pos_1pe = missing, threshold = missing, a_grid_wl_sg, obj, report_simple = missing, report_fit = missing)
            @testset "SiPM: Objective vs. Window length" begin
                @test_nowarn LegendMakie.lplot(report_obj, title = "Test")
            end
        end

        @testset "PMT single-photoelectron fit" begin
            # report as returned by LegendSpecFits.fit_pmt_spe
            pe1(x) = 20_000 * exp(-((x - 17) / 6)^2 / 2) / (6 * sqrt(2π))
            pe2(x) = 2_000 * exp(-((x - 34) / (sqrt(2) * 6))^2 / 2) / (sqrt(2) * 6 * sqrt(2π))
            expo(x) = x >= 4 ? 3_000 / 3 * exp(-(x - 4) / 3) : NaN
            h = StatsBase.fit(StatsBase.Histogram, vcat(abs.(0.8 .+ 0.3 .* randn(50_000)), 4 .- 3 .* log.(rand(3_000)),
                                                        17 .+ 6 .* randn(20_000), 34 .+ 8.5 .* randn(2_000)), 0:1.0:100)
            centers = StatsBase.midpoints(first(h.edges))
            fitted = centers .>= 4
            gof = (converged = true, pvalue = 0.4, chi2 = 98.0, dof = 90, covmat = zeros(6, 6),
                   residuals = zeros(count(fitted)), residuals_norm = randn(count(fitted)), bin_centers = centers[fitted])
            report = (h = h, f_fit = x -> x >= 4 ? expo(x) + pe1(x) + pe2(x) : NaN,
                      f_components = (exponential = expo, pe1 = pe1, pe2 = pe2),
                      x_min = 4.0, μ1 = Measurements.measurement(17.0, 0.1), gof = gof)
            @test_nowarn lplot(report, title = "Test")
            @test_nowarn lplot(report, show_components = false, show_residuals = false, legend_position = :none, yscale = Makie.identity)
            @test_nowarn lplot(merge(report, (gof = (converged = false,),)))
        end

        @testset "DPLMS recipes" begin
            n_pre, n_post = 25, 25
            n = n_pre + n_post + 1
            t = (0:199) .* 128.0u"ns"
            superpulse = RadiationDetectorSignals.RDWaveform(t, [1 / (1 + exp(-(i - 100) / 2)) for i in 1:200])
            response = [RadiationDetectorSignals.RDWaveform(t, superpulse.signal .* (1 + 0.01k)) for k in 1:3]
            t50 = fill(t[100], 10)
            t_pickoff = n_post * 128.0u"ns"
            grid = [(nm = 1.0, za = 1e3, ft = 1.0, ct = 0.0, ff = ff) for ff in (2, 4, 6)]
            coeffs = [randn(n) for _ in grid]
            ref = superpulse.signal[(100 - n_pre):(100 + n_post)]
            ref_bins = hcat(ref, ref .* 0.99)
            A = randn(n, n)
            noise = A * A'
            flattops = Dict(ff => A' * A for ff in (2, 4, 6))
            @test lplot((; superpulse, ref, ref_bins, t50, t_pickoff, n_pre, n_post); title = "Test") isa Makie.Figure
            @test lplot((; coeffs, grid, superpulse, t_pickoff, n_pre, n_post); rt = 1.0u"µs", ft = 0.5u"µs") isa Makie.Figure
            @test_throws ArgumentError lplot((; coeffs, grid, superpulse, t_pickoff, n_pre, n_post))
            @test lplot((; superpulse, response, grid, t50, t_pickoff, n_pre, n_post)) isa Makie.Figure
            @test lplot((; noise, flattops, ref, superpulse, n_pre, n_post); ff = 4) isa Makie.Figure
        end

        @testset "Energy calibration" begin
            # a fixed spectrum: some random ones make the peak fits fail
            Random.seed!(1234)
            ecal = filter(x -> x <= 265_000, vcat(rand(Distributions.Exponential(70_000),97_000), 261_450 .+ 200 .* randn(2_000), 210_350 .+ 185 .* randn(500), 159_300 .+ 170 .* randn(500)))
            lines = [:Tl208DEP, :Tl208SEP, :Tl208FEP]
            energies = [1592.513, 2103.512, 2614.511]u"keV"
            result_autocal, report_autocal = LegendSpecFits.autocal_energy(ecal, energies, α = 0.01, rtol = 5e-3)
            @testset "Autocal energy" begin
                @test_nowarn LegendMakie.lplot(report_autocal, energies, title = "Test")
            end
            result_simple, report_simple = LegendSpecFits.simple_calibration(ecal, energies, [25, 25, 35]u"keV", [25, 25, 30]u"keV", calib_type = :th228)
            @testset "Simple energy calibration" begin
                @test_nowarn lplot(report_simple)
                @test_nowarn lplot(report_simple, cal = false)
            end
            m_cal_simple = result_simple.c
            result_ctc, report_ctc = LegendSpecFits.ctc_energy(ecal .* m_cal_simple, rand(length(ecal)), 2614.5u"keV", (5u"keV", 5u"keV"), m_cal_simple)
            @testset "Test energy CTC" begin
                @test_nowarn lplot(report_ctc, figsize = (600,600), title = "Test")
            end
            result_fit, report_fit = LegendSpecFits.fit_peaks(result_simple.peakhists, result_simple.peakstats, lines; e_unit=result_simple.unit, calib_type=:th228, m_cal_simple=m_cal_simple)
            @testset "Fit peaks for energy calibration" begin
                @test_nowarn lplot(report_fit, figsize = (600, 400*length(report_fit)), watermark = false, title = "Test")
                # a single peak: the data and the components in one legend, the data alone, no legend, a linear scale
                @test_nowarn lplot(report_fit[:Tl208FEP], legend_position = :rt, title = "Test")
                @test_nowarn lplot(report_fit[:Tl208FEP], show_components = false, legend_position = :lt, title = "Test")
                @test_nowarn lplot(report_fit[:Tl208FEP], legend_position = :none, yscale = identity, title = "Test")
                @test_nowarn lplot(report_fit[:Tl208FEP], show_label = false, title = "Test")
            end
            μ_fit = getfield.(getindex.(Ref(result_fit), lines), :centroid)
            result_calib, report_calib = LegendSpecFits.fit_calibration(1, μ_fit, energies)
            @testset "Fit energy calibration" begin
                @test_nowarn lplot(report_calib, xerrscaling=10, yerrscaling=10, additional_pts=(μ = [100_000], peaks = [1000u"keV"]), title = "Test")
                @test_nowarn lplot(report_calib, xerrscaling=10, yerrscaling=10, additional_pts=(μ = [], peaks = []), title = "Test")
                @test_nowarn lplot(report_calib, xerrscaling=10, yerrscaling=10, title = "Test")
            end
            f_cal_widths(x) = report_calib.f_fit(x) .* report_calib.e_unit .- first(report_calib.par)
            fwhm_fit = f_cal_widths.(getfield.(getindex.(Ref(result_fit), lines), :fwhm))
            result_fwhm, report_fwhm = LegendSpecFits.fit_fwhm(1, energies, fwhm_fit, uncertainty=true)
            @testset "FWHM energy calibration" begin
                @test_nowarn lplot(report_fwhm, additional_pts=(peaks = [1000u"keV"], fwhm = [3.5u"keV"]), title = "Test")
                @test_nowarn lplot(report_fwhm, additional_pts=(peaks = [], fwhm = []), title = "Test")
                @test_nowarn lplot(report_fwhm, title = "Test")
            end
            @testset "Throw warning for wrong report types" begin
                report_calib_faulty = NamedTuple{keys(report_calib)}((k == :type) ? (:faulty) : report_calib[k] for k in keys(report_calib))
                report_fwhm_faulty = NamedTuple{keys(report_fwhm)}((k == :type) ? (:faulty) : report_fwhm[k] for k in keys(report_fwhm))
                @test_logs (:warn,) lplot(report_calib_faulty, xerrscaling=10, yerrscaling=10, additional_pts=(μ = [100_000], peaks = [1000u"keV"]), title = "Test")
                @test_logs (:warn,) lplot(report_fwhm_faulty, xerrscaling=10, yerrscaling=10, additional_pts=(μ = [100_000], peaks = [1000u"keV"]), title = "Test")
            end
        end

        @testset "A/E correction" begin
            # generate fake A/E distribution
            e_cal = rand(Distributions.Exponential(300), 5_000_000) .+ 300
            μA, μB, σA, σB = 1.01, 4e-6, 5e-3, 12.0
            myμ(E) = μA - μB * E
            myσ(E) = sqrt(σA^2 + σB^2/E^2)
            aoe = [let _μ = myμ(E), _σ = myσ(E); (rand() < 0.2 ? -rand(Distributions.Exponential(5*_σ)) : 0) + _σ*randn() + _μ; end for E in e_cal]

            # A/E vs. E 2D histogram
            h_aoe = StatsBase.fit(StatsBase.Histogram, (e_cal, aoe), (0:0.5:3000, 0.1:5e-3:1.8))
            @test_nowarn lhist(h_aoe, rasterize = true, title = "Test")

            compton_bands = collect((550:50:2350)u"keV")
            compton_window = 20u"keV"
            compton_band_peakhists = LegendSpecFits.generate_aoe_compton_bands(aoe, e_cal*u"keV", compton_bands, compton_window)
            result_fit, report_fit = LegendSpecFits.fit_aoe_compton(compton_band_peakhists.peakhists, compton_band_peakhists.peakstats, compton_bands, uncertainty=true)
            μs = [result_fit[band].μ for band in compton_bands]
            σs = [result_fit[band].σ for band in compton_bands]
            result_fit_single, report_fit_single = LegendSpecFits.fit_aoe_corrections(compton_bands, μs, σs)
            result_fit_combined, report_fit_combined = LegendSpecFits.fit_aoe_compton_combined(compton_band_peakhists.peakhists, compton_band_peakhists.peakstats, compton_bands, result_fit_single, uncertainty=true)

            # Compton band (individual) fit
            @test_nowarn lplot(report_fit[first(compton_bands)])

            # A/E correction plots
            @test_nowarn lplot(report_fit_single.report_μ, col = 1, figsize = (1200,420))
            @test_nowarn lplot!(report_fit_single.report_σ, col = 2)

            # A/E combined fit plots
            @test_nowarn lplot(report_fit_single.report_μ, report_fit_combined.report_μ, col = 1, figsize = (1200,420))
            @test_nowarn lplot!(report_fit_single.report_σ, report_fit_combined.report_σ, col = 2)
        end

        @testset "A/E cut histogram" begin
            # generate fake A/E distribution and energy histogram
            aoe = vcat(randn(50_000), randn(950_000) .- 3)
            e_cal = vcat(randn(10_000) .+ 1593, rand(Distributions.Exponential(2000), 990_000))*u"keV"
            _, report_cut = LegendSpecFits.get_low_aoe_cut(aoe, e_cal)

            # A/E cut histogram
            @test_nowarn lplot(report_cut, figsize = (750,400), title = "Test")
        end

        @testset "A/E ctc correlation plot" begin
            # generate fake A/E and Qdrift/E distribution 
            E0 = 550u"keV"
            e_cal = fill(E0, 100_000)
            aoe_corr = clamp.(vcat(-rand(Distributions.Exponential(5.0), 20_000), zeros(80_000)) .+ randn(100_000), -49.0, 7.0)
            qdrift_e = max.(0, randn(100_000) .+ 5)
            # add some fake drift time dependency
            fct = 0.1
            aoe_corr .-= qdrift_e .* fct
            aoe_corr .-= StatsBase.median(aoe_corr)
            @test length(e_cal) == length(aoe_corr) == length(qdrift_e) == 100_000
            result_aoe_ctc, report_aoe_ctc = LegendSpecFits.ctc_aoe(aoe_corr, e_cal, qdrift_e, [E0-10u"keV"])
            @test_nowarn lplot(report_aoe_ctc, figsize = (600,600), title = "Test")
            @test_nowarn lplot(report_aoe_ctc, norm = true, figsize = (600,600), title = "Test")
        end

        @testset "A/E survival fraction plots" begin
            # generate fake A/E and E distribution
            aoe = vcat(randn(30_000), randn(70_000) .- 10)
            e_cal = 1.5u"keV" .* randn(100_000) .+ 2614.5u"keV"
            result_peaks_ds, report_peaks_ds = LegendSpecFits.get_peaks_survival_fractions(
                aoe, e_cal, [2614.5u"keV"], [:Tl208FEP], [(35.0u"keV",35.0u"keV")], low_cut = -5.0)
            @test_nowarn LegendMakie.lplot(report_peaks_ds[:Tl208FEP], sf_in_title = true, title = "Test")
            @test_nowarn LegendMakie.lplot(report_peaks_ds[:Tl208FEP], sf_in_title = false, title = "Test")
            @test_nowarn LegendMakie.lplot(report_peaks_ds, title = "Test")
            @test_nowarn LegendMakie.lplot(report_peaks_ds, sf_in_title = false, title = "Test")
        end

        @testset "LQ plots" begin
            e_cal = filter(x -> x <= 2650u"keV", vcat(rand(Distributions.Exponential(700),97_000)u"keV", 2614.5u"keV" .+ 2u"keV" .* randn(2_000), 2103.5u"keV" .+ 1.85u"keV" .* randn(500), 1593.5u"keV" .+ 1.7u"keV" .* randn(500)))
            dt_eff = rand(length(e_cal))*10 .+ 3
            lq_e_corr = filter(x -> -20 < x < 20, clamp.(rand(Distributions.Cauchy(1.0, 0.5), 2*length(e_cal)),-20,20))[eachindex(e_cal)] .+ dt_eff .* 0.01
            drift_result, drift_report = LegendSpecFits.lq_ctc_correction(lq_e_corr, dt_eff, e_cal, 1593.5u"keV", 1.5u"keV")
            result, report = LegendSpecFits.lq_norm(1593.5u"keV", 1.5u"keV", e_cal, lq_e_corr)
            @test_nowarn lplot(drift_report, e_cal, dt_eff, lq_e_corr, :whole, title = "Test", figsize = (620,400))
            @test_nowarn lplot(drift_report, e_cal, dt_eff, lq_e_corr, :DEP, title = "Test", figsize = (620,400))
            @test_nowarn lplot(report.temp_hists, title = "Test")
            @test_nowarn lplot((; e_cal, edges = report.edges, dep_σ = report.dep_σ), title = "Test")
            @test_nowarn lplot((; e_cal, lq_class = lq_e_corr, cut_value = 3.0), figsize = (750,400), title = "Test")
        end

        @testset "SiPM plots" begin 
            # generate SiPM thresholds as normal distribution with standard deviation 0
            result_thres, report_thres = LegendSpecFits.fit_sipm_threshold(randn(100_000), -5.0, 5.0)
            @test_nowarn LegendMakie.lplot(report_thres, title = "Test")

            # generate fake SiPM amplitude spectrum with 5 P.E. peaks and some background
            e_uncal = vcat([randn(round(Int, exp10(6-0.5*i))).*0.3 .+ i*1.4 for i in Base.OneTo(5)]..., randn(10000).*1.5 .+ 6)
            result_simple, report_simple = LegendSpecFits.sipm_simple_calibration(e_uncal, n_fwhm_noise_cut=0.0)
            result_fit, report_fit = LegendSpecFits.fit_sipm_spectrum(report_simple.pe_simple_cal, 0.5, 4.5, n_mixtures=8,Δpe_peak_assignment=0.5)
            result_calib, report_calib = LegendSpecFits.fit_calibration(1, result_fit.positions, collect(result_fit.peaks) * u"eV/V")
            @test_nowarn LegendMakie.lplot(report_simple, title = "Test")
            @test_nowarn LegendMakie.lplot(report_simple, cal = false, title = "Test")
            @test_nowarn LegendMakie.lplot(report_fit, xerrscaling = 5, title = "Test")
            @test_nowarn LegendMakie.lplot(report_calib, xerrscaling = 5, title = "Test")
        end

        @testset "Parameter plots" begin
            l200 = LegendDataManagement.LegendData(:l200)
            filekey = LegendDataManagement.start_filekey(l200, :p02, :r000, :cal)
            dets = l200.metadata.hardware.detectors.germanium.diodes
            chinfo = LegendDataManagement.channelinfo(l200, filekey, system = :geds)
            pd = PropDicts.PropDict(Dict(Symbol.(det.name) => det.production.mass_in_g for det in dets))
            @test_nowarn LegendMakie.lplot(chinfo, pd)
            # delete the last entry to test handling missing detectors
            delete!(pd, :V99000A)
            @test_logs (:warn,) LegendMakie.lplot(chinfo, pd)
            # Check status colors and the missing-data line with the same channel metadata.
            @test_logs (:warn,) LegendMakie.lplot(chinfo, pd; detector_status_colors = true, watermark = false)
        end
    end

    @testset "Test event plot" begin
        
        # create lh5 test directory
        testdir = joinpath(dirname(dirname(pathof(LegendMakie))), "test","lh5")
        isdir(testdir) && rm(testdir, force = true, recursive = true)
        mkdir(testdir)
        @test isdir(testdir)

        # link it in the legend data config
        pd = PropDicts.readprops(julia_config)
        pd.setups.l200.paths[Symbol("tier/raw")] = testdir
        # pd.setups.l200.paths[Symbol("tier/raw")] 
        PropDicts.writeprops(joinpath(testdir, "test_config.json"), pd)
        ENV["LEGEND_DATA_CONFIG"] = joinpath(testdir, "test_config.json");
        data = LegendDataManagement.LegendData(:l200)

        # create fake data for the two runs used below
        fk_cal = LegendDataManagement.start_filekey(data, :p02, :r006, :cal)
        fk_phy = LegendDataManagement.start_filekey(data, :p02, :r006, :phy)
        for fk in (fk_cal, fk_phy)
            raw_path = data.tier[:raw, fk]
            mkpath(dirname(raw_path))
            #create fake files
            chinfo = LegendDataManagement.channelinfo(data, fk, system = :geds)
            LegendHDF5IO.lh5open(raw_path, "w") do h
                for det in chinfo.detector
                    h["raw/$(det)"] = TypedTables.Table(
                        timestamp = [Dates.datetime2unix(Dates.DateTime(fk))u"s" + 100u"s"],
                        baseline = [UInt16(100)], presum_rate = [UInt16(8)],
                        waveform_presummed = [RadiationDetectorSignals.RDWaveform(range(0u"μs", 128u"μs", length = 1000), rand(UInt8, 1000))],
                        waveform_windowed = [RadiationDetectorSignals.RDWaveform(range(0u"μs", 128u"μs", length = 1000), rand(UInt8, 1000))],
                    )
                end
            end
        end

        # plot the event
        t_cal = Dates.datetime2unix(Dates.DateTime(fk_cal))u"s" + 100u"s"
        t_phy = Dates.datetime2unix(Dates.DateTime(fk_phy))u"s" + 100u"s"

        det = LegendDataManagement.DetectorId(:V99000A)
        @testset "Event plots" begin 
            @test_nowarn LegendMakie.lplot(data, t_cal, figsize = (800,600), xlims = (0,128))
            # the test data holds no SiPM channels: the default `system` warns about them; other
            # warnings, e.g. deprecations in dependencies, are ignored
            @test_logs (:warn, r"No processable channels found for system spms") match_mode = :any LegendMakie.lplot!(data, t_phy, xlims = (0,128))
            @test LegendMakie.lplot(data, t_phy).scene.viewport[].widths == [800, 600]
            @test_nowarn LegendMakie.lplot(data, t_phy; system = :geds)
            @test_nowarn LegendMakie.lplot(data, t_phy; system = [:geds])
            @test_nowarn LegendMakie.lplot(data, t_phy, figsize = (800,600), xlims = (0,128); system=Dict(:geds => [:waveform_windowed]))
            @test_nowarn LegendMakie.lplot(data, t_phy, figsize = (800,600), xlims = (0,128); system = :geds, subtract_baseline = false)
            @test_nowarn LegendMakie.lplot(data, t_phy; system = :geds, only_processable = false)
            @test_throws ArgumentError LegendMakie.lplot(data, t_phy; system = :pmts)
            # the grouping of the channels, one panel per group, and a filter on the channel information
            @test_nowarn LegendMakie.lplot(data, t_phy; system = :geds, group = true, color = :group)
            @test_nowarn LegendMakie.lplot(data, t_phy; system = :geds, group = :hvcard, color = :group)
            @test_nowarn LegendMakie.lplot(data, t_phy; system = :geds, group = Dict(:geds => :cc4), color = :group)
            @test LegendMakie.lplot(data, t_phy; system = :geds, exploded = true).scene.viewport[].widths == [1200, 900]
            @test_nowarn LegendMakie.lplot(data, t_phy; system = :geds, exploded = true, group = :hvcard, ncols = 1)
            @test_nowarn LegendMakie.lplot(data, t_phy; system = :geds, filterby = r -> r.detector == det)
            @test_nowarn LegendMakie.lplot(data, t_phy; system = :geds, filterby = Dict(:geds => r -> r.detstring == 1))
            @test_throws ArgumentError LegendMakie.lplot(data, t_phy; system = :geds, filterby = r -> false)
            # a grouping colors the channels by group unless `color` says otherwise
            @test any(c -> c isa Makie.Legend, LegendMakie.lplot(data, t_phy; system = :geds, group = :cc4).content)
            @test !any(c -> c isa Makie.Legend, LegendMakie.lplot(data, t_phy; system = :geds).content)
            @test !any(c -> c isa Makie.Legend, LegendMakie.lplot(data, t_phy; system = :geds, group = :cc4, color = :amplitude).content)
            # channels colored by amplitude, group or one by one
            @test LegendMakie.lplot(data, t_phy; system = :geds, color = :group) isa Makie.Figure
            @test LegendMakie.lplot(data, t_phy; system = :geds, color = :channel) isa Makie.Figure
            @test LegendMakie.lplot(data, t_phy; system = :geds, exploded = true, color = :channel) isa Makie.Figure
            @test LegendMakie.lplot(data, t_phy; system = :geds, exploded = true, color = :group) isa Makie.Figure
            @test_throws ArgumentError LegendMakie.lplot(data, t_phy; system = :geds, color = :rainbow)
            @test_throws ArgumentError LegendMakie.lplot(data, t_phy; system = :geds, color = :group, group = false)
            @test_nowarn LegendMakie.lplot(data, Dates.DateTime(Dates.unix2datetime(t_cal ./ u"s")))
        end

        @testset "Detector plots" begin 
            @test lplot(data, t_cal, det, figsize = (800,380), xlims = (0,128)) isa Makie.Figure
            @test lplot(data, t_cal, det).scene.viewport[].widths == [800, 400]
            @test_throws ArgumentError lplot(data, t_cal .+ 1u"s", det, figsize = (800,380), xlims = (0,128))
            @test lplot(data, t_phy, det, figsize = (800,380), xlims = (0,128), show_label = false) isa Makie.Figure
            @test lplot(data, t_phy, det, figsize = (800,380), xlims = (0,128), subtract_baseline = false) isa Makie.Figure
        end

        @testset "Event display" begin
            ext = Base.get_extension(LegendMakie, :LegendMakieLegendDataManagementExt)
            DetId = LegendDataManagement.DetectorId

            lar = (; spm_windows = ["prompt", "delayed"], is_valid_lar = "!trig_max_trap_cal_all_lar_cut",
                energy_types = PropDicts.PropDict(
                    :trig_max_trap_cal => PropDicts.PropDict(:pos => "trig_pos_trap", :is_dc => "trig_max_trap_is_dc"),
                    :trig_max_sg_cal => PropDicts.PropDict(:pos => "trig_pos_sg", :is_dc => "trig_max_sg_is_dc")),
                cuts = PropDicts.PropDict(
                    :all => PropDicts.PropDict(:window => "full", :dphi_max => PropDicts.PropDict(:inner => 180.0u"°", :outer => 180.0u"°")),
                    :geom => PropDicts.PropDict(:window => "full", :dphi_max => PropDicts.PropDict(:inner => 180.0u"°", :outer => 45.0u"°")),
                    :geom1 => PropDicts.PropDict(:window => "prompt", :dphi_max => PropDicts.PropDict(:inner => 60.0u"°", :outer => 60.0u"°"))))

            @test ext._lar_energy_type(lar) == :trig_max_trap_cal
            @test_throws "Expected one of the energy types" ext._lar_energy_type(merge(lar, (; is_valid_lar = "!something_else")))
            @test ext._lar_geometric_cut(lar, :geom) == (name = :geom, window = :full, dphi_max = (inner = 180.0, outer = 45.0))
            @test ext._lar_geometric_cut(lar, :geom1) == (name = :geom1, window = :prompt, dphi_max = (inner = 60.0, outer = 60.0))
            @test ext._lar_geometric_cut(lar, nothing) == (name = nothing, window = nothing, dphi_max = (inner = 180.0, outer = 180.0))
            @test_throws "has no cut `geom9`" ext._lar_geometric_cut(lar, :geom9)

            @test ext._wrap_degrees(190.0) == -170.0
            @test ext._dphi_degrees(350.0, 10.0) == 20.0
            @test ext._event_date(1.5u"s") == "1970-01-01 00:00:01.500000 UTC"
            @test ext._event_date(1500u"ms") == "1970-01-01 00:00:01.500000 UTC"

            # two strings with the azimuths 0° and 180°, a module of two SiPMs at each of them
            # in the outer barrel and an inner SiPM at 90°; y runs against the azimuth
            geds = TypedTables.Table(detector = DetId.([:V00001A, :V00002A, :V00003A]), detstring = [1, 1, 2], position = [1, 2, 1],
                x = [200.0, 200.0, -200.0]u"mm", y = [0.0, 0.0, 0.0]u"mm", z = [-500.0, -600.0, -500.0]u"mm", angle = [0.0, 0.0, 180.0]u"°")
            spms = TypedTables.Table(detector = DetId.([:S001, :S002, :S003, :S004, :S005]), barrel = [:outer, :outer, :outer, :outer, :inner],
                x = [280.0, 280.0, -280.0, -280.0, 0.0]u"mm", y = [0.0, 0.0, 0.0, 0.0, -120.0]u"mm", z = [-30.0, -1500.0, -30.0, -1500.0, -60.0]u"mm",
                angle = [0.0, 0.0, 180.0, 180.0, 90.0]u"°", processable = trues(5))
            shapes = [(radius = 40.0, height = 80.0) for _ in 1:3]
            evt = (tstart = 1.5u"s",
                geds = (trig_e_det = DetId.([:V00002A]), trig_e_det_idxs = [2], trig_e_cusp_ctc_cal = [1000.0u"keV"], t0_start = 50.0u"μs",
                    detector = DetId.([:V00001A, :V00002A, :V00003A]), e_cusp_ctc_cal = [1.0, 1000.0, 2.0]u"keV", max_e_cusp_ctc_cal = 1000.0u"keV",
                    aoe_sg_classifier = [0.0, -1.5, 0.0], lq80_250025_classifier = [0.0, 2.5, 0.0], is_valid_qc = true, is_valid_psd = false),
                spms = (detector = DetId.([:S001, :S002, :S003, :S004, :S005]), trig_pos_trap = [[50.0, 51.0], [52.0], [80.0], [51.5], Float64[]] .* 1000u"ns", trig_max_trap_cal = [[2.0, 1.0], [3.0], [9.0], [4.0], Float64[]],
                    trig_max_trap_is_dc = [[false, false], [false], [false], [true], Bool[]]),
                ged_spm = (is_valid_lar = false, spm = (detector = DetId.([:S001, :S002, :S003, :S004]), trig_max_trap_cal_prompt_pe_sum = [2.0, 0.0, 0.0, 0.0],
                    trig_max_trap_cal_delayed_pe_sum = [1.0, 3.0, 0.0, 0.0])),
                ged_pmt = (; is_valid_muon = true))
            array = ext._event_array(geds, spms, shapes, evt, :trig_max_trap_cal, lar, (inner = 180.0, outer = 45.0))
            @test array.main_det == DetId(:V00002A)
            @test array.detectors.triggered == [false, true, false]
            @test array.detectors.in_event == [true, true, true]
            @test [s.triggered for s in array.strings] == [true, false]
            @test array.sipms.pe == [3.0, 3.0, 0.0, 0.0, 0.0]
            @test array.sipms.in_cut == [true, true, false, false, true]
            @test array.sipms.in_event == [true, true, true, true, false]
            @test array.sipms.dphi == [0.0, 0.0, -180.0, -180.0, 90.0]
            @test [m.pe for m in array.modules] == [6.0, 0.0, 0.0]
            @test array.radii == (outer = 280.0, inner = 120.0)

            # a trigger counts in the window of the cut, unless it is flagged as a dark count
            triggers = ext._event_lar_triggers(evt, :trig_max_trap_cal, lar, (-1.5, 5.0))
            @test triggers.times == [0.0, 1.0, 2.0]
            @test triggers.pes == [2.0, 1.0, 3.0]

            # the strokes of a line share one segment and hold every sample in order
            t_long = range(0u"μs", 100u"μs", length = 1001)
            long = RadiationDetectorSignals.ArrayOfRDWaveforms([RadiationDetectorSignals.RDWaveform(t_long, collect(1:1001) .+ k) for k in (0, 5000)])
            x, signals = ext._series_data(long, u"μs")
            @test size(signals, 2) == 2
            @test unique(filter(!isnan, signals[:, 1])) == 1:1001
            @test filter(!isnan, signals[:, 2]) == filter(!isnan, signals[:, 1]) .+ 5000
            @test first(x) == 0 && last(x) == 100
            breaks = findall(isnan, x)
            @test isnan.(signals[:, 1]) == isnan.(x)
            @test all(b -> signals[b + 1, 1] == signals[b - 2, 1] && signals[b + 2, 1] == signals[b - 1, 1], breaks)
            @test all(diff(vcat(0, breaks, length(x) + 1)) .<= ext._stroke_segments + 2)
            short = RadiationDetectorSignals.ArrayOfRDWaveforms([RadiationDetectorSignals.RDWaveform(t_long[1:10], collect(1:10))])
            @test !any(isnan, first(ext._series_data(short, u"μs")))

            # a figure filled from another event equals a figure filled with this event only
            config = (; geds, spms, lar, lar_energy = :trig_max_trap_cal, geometric = ext._lar_geometric_cut(lar, :geom), cut_window = :full, key = 1,
                windows = (full = (-1.5, 5.0), prompt = (-1.5, 0.5), delayed = (0.5, 5.0)))
            t_wf = range(0u"μs", 100u"μs", length = 100)
            panels(n, scale) = [(; sys, tag = string(sys), wvfs = [:wf => RadiationDetectorSignals.ArrayOfRDWaveforms([RadiationDetectorSignals.RDWaveform(t_wf, scale .* sin.(i .* (1:100) ./ 10)) for i in 1:n])],
                colors = Dict(:wf => fill(:red, n)), legend = nothing) for sys in (:geds, :spms)]
            function fill!(d, trig, pe, panel_list)
                event = merge(evt, (; geds = merge(evt.geds, (; trig_e_det = trig, trig_e_det_idxs = indexin(trig, evt.geds.detector), trig_e_cusp_ctc_cal = fill(1.0u"keV", length(trig)))),
                    ged_spm = merge(evt.ged_spm, (; spm = merge(evt.ged_spm.spm, (; trig_max_trap_cal_delayed_pe_sum = pe))))))
                local array = ext._event_array(geds, spms, shapes, event, :trig_max_trap_cal, lar, config.geometric.dphi_max)
                isnothing(d.plots) && ext._build_event_display!(d, array, config)
                local triggers = ext._event_lar_triggers(event, :trig_max_trap_cal, lar, (-1.5, 5.0))
                limits = ext._event_pe_limits(array, triggers, nothing)
                values = (event = [string(length(trig)), "1.0 PE", "2", "1.0 PE", "2"], cuts = ["vetoed", "passed", "not passed", string(length(trig))], triggered = [join(string.(trig), "\n"), join(string.(eachindex(trig)), "\n"), "1", "2", "3"])
                ext._fill_event_panels!(d.plots, "key", "date", values, array, config, triggers, limits)
                isnothing(d.waveforms) && (d.waveforms = ext._build_event_waveforms!(d.waveform_grid, panel_list, d.options))
                ext._fill_event_waveforms!(d.waveforms, panel_list, 50.0, config.windows, config.cut_window, d.options)
                Makie.colorbuffer(d.figure)
            end
            many = (DetId.([:V00002A, :V00003A]), [100.0, 3.0, 0.0, 0.0], panels(3, 500.0))
            none = (DetId.([:V00001A]), [0.0, 0.0, 0.0, 0.0], panels(3, 2.0))
            for (first_event, second_event) in ((many, none), (none, many))
                refilled = LegendMakie.eventdisplay(data)
                fill!(refilled, first_event...)
                fresh = LegendMakie.eventdisplay(data)
                @test fill!(refilled, second_event...) == fill!(fresh, second_event...)
            end

            # the keywords of the waveforms arrange exploded panels, also when filled from another event
            exploded_panels(scale) = [merge(p, (; tag)) for (p, tag) in zip(vcat(panels(3, scale), panels(3, scale)[2]), ("geds: string 1", "spms: barrel IB", "spms: barrel OB"))]
            exploded_display() = LegendMakie.eventdisplay(data; exploded = true, ncols = 2)
            refilled = exploded_display()
            fill!(refilled, DetId.([:V00001A]), [0.0, 0.0, 0.0, 0.0], exploded_panels(2.0))
            image = fill!(refilled, DetId.([:V00002A, :V00003A]), [100.0, 3.0, 0.0, 0.0], exploded_panels(500.0))
            @test image == fill!(exploded_display(), DetId.([:V00002A, :V00003A]), [100.0, 3.0, 0.0, 0.0], exploded_panels(500.0))
            @test length(refilled.waveforms.axs) == 3
            @test refilled.options.exploded && refilled.options.ncols == 2
            @test !LegendMakie.eventdisplay(data).options.exploded

            # a new layout equals a first one, also over the remains of a build that failed
            ref = LegendMakie.eventdisplay(data)
            image = fill!(ref, many...)
            ext._build_event_display!(ref, array, config)
            @test fill!(ref, many...) == image
            failed = LegendMakie.eventdisplay(data)
            @test_throws ErrorException ext._build_event_display!(failed, array, merge(config, (; cut_window = :none)))
            @test isnothing(failed.plots) && !isempty(failed.figure.content)
            ext._build_event_display!(failed, array, config)
            @test fill!(failed, many...) == image

            # the name of a detector stays inside the side view
            far = merge(array, (; detectors = merge(array.detectors, (; dphi = [0.0, 150.0, -170.0], triggered = [true, true, true]))))
            ext._fill_event_side_view!(ref.plots.side_view, far, config.geometric, (0.5, 10.0))
            @test [Makie.to_align(a) for a in ref.plots.side_view.trig_names.align[]] == Makie.to_align.([(:left, :center), (:right, :center), (:left, :center)])
            @test [p[1] for p in ref.plots.side_view.trig_names.arg1[]] ≈ [13.46, 136.54, -156.54] atol = 0.01

            # the observables read the window of each cut and show what is not finite
            windowed = (; config..., geometric = (name = :geom, window = :prompt, dphi_max = (inner = 180.0, outer = 45.0)))
            observed = merge(evt, (; ged_spm = merge(evt.ged_spm, (; trig_max_trap_cal_spms_full_pe_sum = 6.0, trig_max_trap_cal_spms_full_multiplicity = 2,
                trig_max_trap_cal_spms_geom_prompt_pe_sum = 2.0, trig_max_trap_cal_spms_geom_prompt_multiplicity = 1))))
            observables = (; energy = :e_cusp_ctc_cal, aoe = :aoe_sg_classifier, lq = :lq80_250025_classifier)
            text = ext._event_observable_values(observed, array, windowed; observables...)
            @test text.event == ["1000.00 keV", "6.0 PE", "2", "2.0 PE", "1"]
            @test text.cuts == ["vetoed", "passed", "passed", "not passed"]
            @test text.triggered == ["V00002A", "1, 2", "1000.00 keV", "-1.50", "2.50"]
            failed_cuts = merge(observed, (; ged_spm = merge(observed.ged_spm, (; is_valid_lar = true)), ged_pmt = (; is_valid_muon = false), geds = merge(observed.geds, (; is_valid_qc = false, is_valid_psd = true))))
            @test ext._event_observable_values(failed_cuts, array, windowed; observables...).cuts == ["passed", "not passed", "not passed", "passed"]
            undefined = merge(observed, (; geds = merge(observed.geds, (; e_cusp_ctc_cal = [1.0, NaN, 2.0]u"keV", aoe_sg_classifier = [0.0, -Inf, 0.0]))))
            text = ext._event_observable_values(undefined, array, windowed; observables...)
            @test first(text.event) == "NaN keV"
            @test text.triggered[3:4] == ["NaN keV", "-Inf"]

            @test ext._event_pe_limits(array, (; pes = [3.0]), nothing) == (0.5, 10.0)
            @test ext._event_pe_limits(array, (; pes = [0.1, 300.0]), nothing) == (0.1, 300.0)
            @test ext._event_pe_limits(array, (; pes = [3.0]), (1, 2)) == (1, 2)

            # a display takes an empty figure, and a method error of a display needs no hint on loading
            occupied = Makie.Figure()
            Makie.Axis(occupied[1, 1])
            @test_throws "`figure` must be empty" LegendMakie.eventdisplay(data; figure = occupied)
            method_error = try LegendMakie.eventdisplay(1) catch e; e end
            @test method_error isa MethodError && !occursin("to be loaded", sprint(showerror, method_error))

            @test_throws "must be a row of an event tier" LegendMakie.lplot(data, (a = 1,))
            @test_throws "must be a row of an event tier" LegendMakie.lplot!(LegendMakie.eventdisplay(data), (a = 1,))
            no_trigger = merge(evt, (; geds = merge(evt.geds, (; trig_e_det = LegendDataManagement.DetectorId[]))))
            @test_throws "has no triggered HPGe detector" LegendMakie.lplot(data, no_trigger)

            # the traces with a signal: the triggered HPGe detectors and the SiPMs with light, also a
            # dark count and outside the windows of the LAr cut
            channels = ext._event_signal_channels(evt, :trig_max_trap_cal)
            @test channels[:geds] == Set(DetId.([:V00002A]))
            @test channels[:spms] == Set(DetId.([:S001, :S002, :S003, :S004]))
            no_charge = merge(evt, (; spms = merge(evt.spms, (; trig_max_trap_cal = [[2.0, 1.0], [0.0], [9.0], [4.0], Float64[]]))))
            @test ext._event_signal_channels(no_charge, :trig_max_trap_cal)[:spms] == Set(DetId.([:S001, :S003, :S004]))
            with_units = merge(evt, (; spms = merge(evt.spms, (; trig_max_trap_cal = [q .* u"C" for q in evt.spms.trig_max_trap_cal]))))
            @test ext._event_signal_channels(with_units, :trig_max_trap_cal)[:spms] == channels[:spms]

            # the panels hold the selected channels; an event can select no channel of a system
            fk_phy = LegendDataManagement.find_filekey(data, t_phy)
            panels_of(selected; color = :amplitude) = ext._event_panels(data, fk_phy, t_phy, Dict(:geds => [:waveform_presummed]); only_processable = true, filterby = nothing, group = nothing,
                color, exploded = false, plot_tier = LegendDataManagement.DataTier(:raw), subtract_baseline = true, channels = selected)
            one_detector = Dict(:geds => Set([DetId(det)]))
            @test length(last(only(only(panels_of(one_detector)).wvfs))) == 1
            @test length(last(only(only(panels_of(nothing)).wvfs))) > 1
            # a system without an entry keeps all of its channels
            @test length(last(only(only(panels_of(Dict(:spms => Set{DetId}()))).wvfs))) > 1
            @test_logs min_level = Base.CoreLogging.Warn @test_throws "No channels to plot" panels_of(Dict(:geds => Set{DetId}()))
            # an empty selection is expected, a `filterby` without any channel is not
            system_panels(selected; filterby = nothing) = ext._system_panels(data, fk_phy, t_phy, :geds, [:waveform_presummed]; only_processable = true, filterby, group = nothing, color = :amplitude,
                exploded = false, plot_tier = LegendDataManagement.DataTier(:raw), subtract_baseline = true, channels = selected)
            @test isempty(@test_logs min_level = Base.CoreLogging.Warn system_panels(Dict(:geds => Set{DetId}())))
            @test isempty(@test_logs (:warn, r"No processable channels") system_panels(one_detector; filterby = r -> false))

            # the cuts of the event need the column of the muon cut
            @test_throws "ged_pmt" LegendMakie.lplot(data, (; evt.tstart, evt.geds, evt.spms, evt.ged_spm))

            # another legend needs new axes
            legend_panels(labels) = [(; sys = :geds, tag = "geds", wvfs = [:wf => long], legend = ("detector", labels, [:red, :blue]))]
            @test ext._panel_key(legend_panels(["a", "b"])) == ext._panel_key(legend_panels(["a", "b"]))
            @test ext._panel_key(legend_panels(["a", "b"])) != ext._panel_key(legend_panels(["a", "c"]))
            @test LegendMakie.eventdisplay(data).options.show_empty_traces
            @test !LegendMakie.eventdisplay(data; show_empty_traces = false).options.show_empty_traces

            # the workload of the precompilation runs, and leaves the names of Base to Base
            @test isnothing(ext._event_display_workload())
            @test !any(n -> isdefined(Base, n) && getglobal(ext, n) !== getglobal(Base, n), filter(n -> isdefined(ext, n) && n in names(Base), names(ext, all = true)))

            # one event from a row or from a time, whose row is read from the event tier
            @test_throws "must be a row of an event tier" LegendMakie.eventdisplay(data, (a = 1,))
            @test_throws "has no triggered HPGe detector" LegendMakie.eventdisplay(data, no_trigger)
            @test_throws "jlevt" LegendMakie.eventdisplay(data, t_phy)
            @test_throws "jlevt" LegendMakie.lplot!(LegendMakie.eventdisplay(data), t_phy)
            @test_throws "jlskm" LegendMakie.eventdisplay(data, t_phy; event_tier = :jlskm)
            @test_throws "jlskm" LegendMakie.lplot!(LegendMakie.eventdisplay(data), t_phy; event_tier = LegendDataManagement.DataTier(:jlskm))
        end

        # remove test repository
        isdir(testdir) && rm(testdir, force = true, recursive = true)
    end
end
