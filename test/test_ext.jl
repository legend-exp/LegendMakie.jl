# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Test

@testset "Test correct loading of extensions" begin
    @test isnothing(Base.get_extension(LegendMakie, :LegendMakieMakieExt))
    @test isnothing(Base.get_extension(LegendMakie, :LegendMakieLegendDataManagementExt))
    @test isnothing(Base.get_extension(LegendMakie, :LegendMakieLegendSpecFitsExt))

    import Makie
    @test !isnothing(Base.get_extension(LegendMakie, :LegendMakieMakieExt))

    import LegendSpecFits
    @test !isnothing(Base.get_extension(LegendMakie, :LegendMakieLegendSpecFitsExt))

    import LegendDataManagement
    @test !isnothing(Base.get_extension(LegendMakie, :LegendMakieLegendDataManagementExt))
end