# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

import Test
import Aqua
import LegendMakie

Test.@testset "Package ambiguities" begin
    Test.@test isempty(Test.detect_ambiguities(LegendMakie))
end # testset

Test.@testset "Aqua tests" begin
    Aqua.test_all(
        LegendMakie,
        ambiguities = true,
        # PrecompileTools is used only by the package extensions
        stale_deps = (ignore = [:PrecompileTools],),
    )
end # testset
