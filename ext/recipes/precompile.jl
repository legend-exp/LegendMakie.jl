# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

# Builds figures on synthetic data so that the plot recipes are compiled at package
# precompilation. Nothing is rendered: a Makie backend is not a dependency.
PrecompileTools.@setup_workload begin
    values = [sin(i) + cos(0.37i) for i in 1:200]
    PrecompileTools.@compile_workload begin
        Makie.with_theme(LegendTheme) do
            for fig in (
                LegendMakie.lhist(values; bins = -2:0.2:2, xlabel = "Energy (keV)", title = "Title"),
                LegendMakie.lhist(values, reverse(values); bins = (10, 10), title = "Title")
            )
                Base.empty!(fig)
            end
        end
    end
end
