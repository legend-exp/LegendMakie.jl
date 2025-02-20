# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie

import LegendSpecFits

using Test

@testset "lplot" begin
    @testset "Test watermarks" begin

        fig = Figure()

        # test default watermark
        ax = Axis(fig[1,1])
        hist!(ax, randn(10000))
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
    end
end
