# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie

import LegendSpecFits
import Distributions
import StatsBase
import Unitful: @u_str

using Test

@testset "lplot" begin
    @testset "Test watermarks" begin

        fig = Figure()

        # test default watermark
        ax = Axis(fig[1,1])
        @test_nowarn lplot!(StatsBase.fit(StatsBase.Histogram, randn(10000)))
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
    end
end
