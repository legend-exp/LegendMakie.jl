# LegendMakie.jl

Plot recipes of the LEGEND experiment for [Makie](https://docs.makie.org/stable/): the
LEGEND theme, watermarks, histograms, waveforms and events of the LEGEND-200 data, and the
reports of [LegendSpecFits](https://github.com/legend-exp/LegendSpecFits.jl).

The recipes live in package extensions: they are available once a Makie backend such as
`CairoMakie` is loaded, together with the package whose types they draw
(`LegendSpecFits`, `LegendDataManagement`, `RadiationDetectorSignals`).

The [Recipes](@ref "Histograms and watermarks") pages show every recipe on data built from
random numbers and the metadata of [LegendTestData](https://github.com/legend-exp/LegendTestData.jl);
their code runs when the documentation is built.
