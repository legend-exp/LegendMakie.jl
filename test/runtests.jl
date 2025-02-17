# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

import Test

Test.@testset "Package LegendMakie" begin
    include("test_aqua.jl")
    include("test_lmplot.jl")
    include("test_rdsignals.jl")
    include("test_docs.jl")
end # testset
