# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

using LegendMakie
using Makie, CairoMakie
using Test

import RadiationDetectorSignals
import Unitful: @u_str

@testset "RadiationDetectorSignals" begin
    wf = RadiationDetectorSignals.RDWaveform(range(0u"μs", 128u"μs", length = 1000), rand(1000))
    wfs = RadiationDetectorSignals.ArrayOfRDWaveforms([wf, wf])
    @test_nowarn lplot(wf)
    @test_nowarn lplot(wf, title = "Test", label = "Waveform")
    @test_nowarn lplot(wfs, xlims = (0, 64), label = ["First", "Second"], color = :red)
    @test_nowarn lplot([wf, wf], xunit = u"ns", legend_position = :none)
    @test lplot(wfs) isa Makie.Figure
    @test_throws ArgumentError lplot(wfs, label = ["Only one"])
end
