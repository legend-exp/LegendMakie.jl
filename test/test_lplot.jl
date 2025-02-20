# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie

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
        hist!(ax2, randn(10000))
        @test_nowarn LegendMakie.add_watermarks!(legend_logo = true, position = "outer top", preliminary = false)
    end
end
