# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie, CairoMakie

import LegendSpecFits
import LegendDataManagement
import LegendHDF5IO
import LegendTestData
testdata_dir = joinpath(LegendTestData.legend_test_data_path(), "data", "legend")
ENV["LEGEND_DATA_CONFIG"] = joinpath(testdata_dir, "config.json")

import Dates
import Distributions
import Measurements
import PropDicts
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
            t = Table(x1 = randn(1000000), x2 = randn(1000000))
            config = PropDict(
                :x1 => PropDict(:min => -10.0, :max => 10.0, :sigma => 2.0,
                    :kwargs => PropDict(:relative_cut => 0.01, :n_bins => -1, :fixed_center => false, :left => false)
                ),
                :x2 => PropDict(:min => -10.0, :max => 10.0, :sigma => 2.0,
                    :kwargs => PropDict(:relative_cut => 0.01, :n_bins => -1, :fixed_center => false, :left => true)
                ))
            
            result, report = qc_window_cut(t, config, (:x1, :x2))
            @test_nowarn lplot(report, title = "Test")
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
            e_grid_ft = (1.5:0.5:16.0)u"μs"
            fwhm = Measurements.measurement.(rand(length(e_grid_ft)) .* 5.0 .+ 2.0, NaN)u"keV"
            min_fwhm, idx = findmin(fwhm)
            ft = Measurements.measurement(e_grid_ft[idx], step(e_grid_ft))
            report_ft = (; ft, min_fwhm, e_grid_ft, fwhm)
            @testset "FWHM vs. Flat-Top Time" begin
                @test_nowarn LegendMakie.lplot(report_ft, title = "Test")
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

        @testset "Energy calibration" begin
            ecal = filter(x -> x <= 265_000, vcat(rand(Distributions.Exponential(70_000),97_000), 261_450 .+ 200 .* randn(2_000), 210_350 .+ 185 .* randn(500), 159_300 .+ 170 .* randn(500)))
            lines = [:Tl208DEP, :Tl208SEP, :Tl208FEP]
            energies = [1592.513, 2103.512, 2614.511]u"keV"
            result_autocal, report_autocal = LegendSpecFits.autocal_energy(ecal, energies, α = 0.01, rtol = 2)
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
                aoe, e_cal, [2614.5u"keV"], [:Tl208FEP], [(35.0u"keV",35.0u"keV")], -5.0)
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
            result_fit, report_fit = LegendSpecFits.fit_sipm_spectrum(result_simple.pe_simple_cal, 0.5, 4.5, n_mixtures=8,Δpe_peak_assignment=0.5)
            result_calib, report_calib = LegendSpecFits.fit_calibration(1, result_fit.positions, collect(result_fit.peaks) * u"eV/V")
            @test_nowarn LegendMakie.lplot(report_simple, title = "Test")
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
        end
    end

    @testset "Test event plot" begin
        
        # create lh5 test directory
        testdir = joinpath(dirname(dirname(pathof(LegendMakie))), "test","lh5")
        isdir(testdir) && rm(testdir, force = true, recursive = true)
        mkdir(testdir)
        @test isdir(testdir)

        # link it in the legend data config
        pd = PropDicts.readprops(LegendTestData.activate_legend_test_data_config())
        pd.setups.l200.paths[Symbol("tier/raw")] = testdir
        # pd.setups.l200.paths[Symbol("tier/raw")] 
        PropDicts.writeprops(joinpath(testdir, "test_config.json"), pd)
        ENV["LEGEND_DATA_CONFIG"] = joinpath(testdir, "test_config.json");
        data = LegendDataManagement.LegendData(:l200)
        
        # create fake data
        for fk in [LegendDataManagement.runinfo(data).phy.startkey; LegendDataManagement.runinfo(data).cal.startkey]
            _, period, run, cat, time = split(string(fk), "-")
            !isdir(joinpath(testdir, cat)) && mkdir(joinpath(testdir, cat))
            !isdir(joinpath(testdir, cat, period)) && mkdir(joinpath(testdir, cat, period))
            !isdir(joinpath(testdir, cat, period, run)) && mkdir(joinpath(testdir, cat, period, run))
            #create fake files
            chinfo = LegendDataManagement.channelinfo(data, fk, system = :geds)
            LegendHDF5IO.lh5open(joinpath(testdir, cat, period, run, "$(fk)-tier_raw.lh5"), "w") do h
                for ch in chinfo.channel
                    h["$(ch)/raw"] = TypedTables.Table(
                        timestamp = [Dates.datetime2unix(Dates.DateTime(fk))u"s" + 100u"s"],
                        waveform_presummed = [RadiationDetectorSignals.RDWaveform(range(0u"μs", 128u"μs", length = 1000), rand(UInt8, 1000))],
                        waveform_windowed = [RadiationDetectorSignals.RDWaveform(range(0u"μs", 128u"μs", length = 1000), rand(UInt8, 1000))],
                    )
                end
            end
        end

        # plot the event
        ch = LegendDataManagement.ChannelId(11)
        t_cal = 1.6786153e9u"s"
        t_phy = 1.6787017e9u"s"

        @testset "Event plots" begin 
            @test_nowarn lplot(data, t_cal, figsize = (800,600), xlims = (0,128))
            @test_nowarn lplot(data, t_phy, figsize = (800,600), xlims = (0,128))
            @test_nowarn lplot(data, Dates.DateTime(Dates.unix2datetime(t_cal ./ u"s")))
        end

        @testset "Channel plots" begin 
            @test_nowarn lplot(data, t_cal, ch, figsize = (800,380), xlims = (0,128))
            @test_throws ArgumentError lplot(data, t_cal .+ 1u"s", ch, figsize = (800,380), xlims = (0,128))
            @test_nowarn lplot(data, t_phy, ch, figsize = (800,380), xlims = (0,128), show_label = false)
        end
        
        # remove test repository
        isdir(testdir) && rm(testdir, force = true, recursive = true)
    end
end
