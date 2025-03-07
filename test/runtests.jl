# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

import Test

# checkout main branch of LegendSpecFits
import Pkg; Pkg.add(url = "https://github.com/legend-exp/LegendSpecFits.jl", rev="main")

Test.@testset "Package LegendMakie" begin
    include("test_aqua.jl")
    include("test_ext.jl")
    include("test_lplot.jl")
    include("test_rdsignals.jl")
    include("test_docs.jl")
end # testset
