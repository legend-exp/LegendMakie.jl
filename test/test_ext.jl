# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Test

@testset "Test correct loading of extensions" begin

    # no extension and no LegendTheme defined
    @test isnothing(Base.get_extension(LegendMakie, :LegendMakieMakieExt))
    @test isnothing(Base.get_extension(LegendMakie, :LegendMakieLegendDataManagementExt))
    @test isnothing(Base.get_extension(LegendMakie, :LegendMakieLegendSpecFitsExt))
    @test ismissing(LegendTheme)

    # define LegendTheme and load Makie extension
    import Makie
    @test !isnothing(Base.get_extension(LegendMakie, :LegendMakieMakieExt))
    @test !ismissing(LegendTheme)

    # load LegendSpecFits extension
    import LegendSpecFits
    @test !isnothing(Base.get_extension(LegendMakie, :LegendMakieLegendSpecFitsExt))

    # load LegendDataManagement extension
    import LegendDataManagement
    @test !isnothing(Base.get_extension(LegendMakie, :LegendMakieLegendDataManagementExt))
end