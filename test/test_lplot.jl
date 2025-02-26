# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie

import LegendSpecFits
import LegendDataManagement
import LegendTestData
testdata_dir = joinpath(LegendTestData.legend_test_data_path(), "data", "legend")
ENV["LEGEND_DATA_CONFIG"] = joinpath(testdata_dir, "config.json")

import Distributions
import PropDicts
import StatsBase
import Unitful: @u_str

using Test

@testset "lplot" begin
    @testset "Test watermarks" begin

        fig = Figure()

        # test default watermark
        ax = Axis(fig[1,1])
        lplot!(StatsBase.fit(StatsBase.Histogram, randn(10000)))
        @test_nowarn LegendMakie.add_watermarks!()

        # test alternative watermark
        ax2 = Axis(fig[1,2])
        @test_nowarn LegendMakie.residualplot!(ax2, (x = 1:10, residuals_norm = randn(10)))
        @test_nowarn LegendMakie.add_watermarks!(legend_logo = true, position = "outer top", preliminary = false)
    end

    @testset "Test LegendSpecFits reports" begin
        @testset "Singlefits" begin
            result, report = LegendSpecFits.fit_single_trunc_gauss(randn(10000), (low = -4.0, high = 4.0, max = NaN))
            @test_nowarn lplot(report, xlabel = "x")
        end

        @testset "Energy calibration" begin
            ecal = filter(x -> x <= 265_000, vcat(rand(Distributions.Exponential(70_000),97_000), 261_450 .+ 200 .* randn(2_000), 210_350 .+ 185 .* randn(500), 159_300 .+ 170 .* randn(500)))
            lines = [:Tl208DEP, :Tl208SEP, :Tl208FEP]
            energies = [1592.513, 2103.512, 2614.511]u"keV"
            result_simple, report_simple = LegendSpecFits.simple_calibration(ecal, energies, [25, 25, 35]u"keV", [25, 25, 30]u"keV", calib_type = :th228)
            @testset "Simple energy calibration" begin
                @test_nowarn lplot(report_simple)
                @test_nowarn lplot(report_simple, cal = false)
            end
            m_cal_simple = result_simple.c
            result_fit, report_fit = LegendSpecFits.fit_peaks(result_simple.peakhists, result_simple.peakstats, lines; e_unit=result_simple.unit, calib_type=:th228, m_cal_simple=m_cal_simple)
            @testset "Fit peaks for energy calibration" begin
                @test_nowarn lplot(report_fit, figsize = (600, 400*length(report_fit)), watermark = false)
            end
            μ_fit = getfield.(getindex.(Ref(result_fit), lines), :centroid)
            result_calib, report_calib = LegendSpecFits.fit_calibration(1, μ_fit, energies)
            @testset "Fit energy calibration" begin
                @test_nowarn lplot(report_calib, xerrscaling=10, yerrscaling=10, additional_pts=(μ = [100_000], peaks = [1000u"keV"]), title = "Test")
            end
            f_cal_widths(x) = report_calib.f_fit(x) .* report_calib.e_unit .- first(report_calib.par)
            fwhm_fit = f_cal_widths.(getfield.(getindex.(Ref(result_fit), lines), :fwhm))
            result_fwhm, report_fwhm = LegendSpecFits.fit_fwhm(1, energies, fwhm_fit, uncertainty=true)
            @testset "FWHM energy calibration" begin
                @test_nowarn lplot(report_fwhm, additional_pts=(peaks = [1000u"keV"], fwhm = [3.5u"keV"]), title = "Test")
            end
        end

        @testset "A/E correction" begin
            # generate fake A/E distribution
            e_cal = rand(Distributions.Exponential(300), 5_000_000) .+ 300
            μA, μB, σA, σB = 1.01, 4e-6, 5e-3, 12.0
            myμ(E) = μA - μB * E
            myσ(E) = sqrt(σA^2 + σB^2/E^2)
            aoe = [let _μ = myμ(E), _σ = myσ(E); (rand() < 0.2 ? -rand(Distributions.Exponential(5*_σ)) : 0) + _σ*randn() + _μ; end for E in e_cal]

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
            e_cal = fill(E0, 10_000)
            aoe_corr = clamp.(vcat(-rand(Distributions.Exponential(5.0), 2_000), zeros(8_000)) .+ randn(10_000), -49.0, 7.0)
            qdrift_e = max.(0, randn(10_000) .+ 5)
            @test length(e_cal) == length(aoe_corr) == length(qdrift_e) == 10_000
            result_aoe_ctc, report_aoe_ctc = LegendSpecFits.ctc_aoe(aoe_corr, e_cal, qdrift_e, [E0-10u"keV"])
            @test_nowarn lplot(report_aoe_ctc, figsize = (600,600))
        end

        @testset "Parameter plots" begin
            l200 = LegendDataManagement.LegendData(:l200)
            filekey = LegendDataManagement.start_filekey(l200, :p02, :r000, :cal)
            dets = l200.metadata.hardware.detectors.germanium.diodes
            chinfo = LegendDataManagement.channelinfo(l200, filekey, system = :geds)
            pd = PropDicts.PropDict(Dict(Symbol.(det.name) => det.production.mass_in_g for det in dets))
            @test_nowarn LegendMakie.lplot(chinfo, pd)
        end
    end
end
