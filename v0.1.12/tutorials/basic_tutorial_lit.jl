# # LegendMakie: Basic Tutorial

# Let us start by creating a simple `Makie` plot.
# 
# For this, you will need to load a `Makie` package, e.g. `CairoMakie`.

using CairoMakie
#md using Random # hide
#md Makie.set_theme!() # reset theme # hide

# You can then compose a plot using the `Makie` API, see the documentation [here](https://docs.makie.org/stable/).
#
# You usually start by creating a `Makie.Figure` and a `Makie.Axis` and by then plotting into the axis. 
# If no axis is passed to the plot functions, `Makie` plots into the `Makie.current_axis()`.
# Always make sure to end the cell with the `Makie.Figure` object or call `Makie.current_figure()`

#md Random.seed!(123) # hide
fig = Figure(size = (400,400))
ax = Axis(fig[1,1], xlabel = "X", ylabel = "Y", limits = ((0,1),(0,1)))
lines!(ax, rand(10), rand(10))
lines!(ax, rand(10), rand(10))
lines!(rand(10), rand(10)) # also plots into ax
lines!(rand(10), rand(10)) # also plots into ax
fig

# `Juleana`-related `Makie` code is collected in the GitHub repository [`LegendMakie`](https://github.com/legend-exp/LegendMakie.jl).
# Add this to your project by running `import Pkg; Pkg.add(url = "https://github.com/legend-exp/LegendMakie.jl")`
#
# `LegendMakie` defines `LegendTheme`, a `Makie` theme that includes the LEGEND style guide.
# Find the documentation on `Makie` themes [here](https://docs.makie.org/dev/explanations/theming/themes).
# 
# When loading `LegendMakie`, the `LegendTheme` is automatically applied
# (The package explicitly runs `update_theme!(LegendTheme)`.)

import LegendMakie
#md update_theme!(LegendMakie.LegendTheme) # hide

# Let us now create a the same figure to see the `LegendTheme` in action.

#md Random.seed!(123) # hide
fig = Figure(size = (400,400))
ax = Axis(fig[1,1], xlabel = "X", ylabel = "Y", limits = ((0,1),(0,1)))
lines!(rand(10), rand(10))
lines!(rand(10), rand(10))
lines!(rand(10), rand(10))
lines!(rand(10), rand(10))
fig

# `LegendMakie` offers a convenience function `add_watermarks!` to add the `Juleana` logo

LegendMakie.add_watermarks!()

# Let us now create a plot with histograms

#md Random.seed!(123) # hide
fig = Figure(size = (600,400))
ax = Axis(fig[1,1], limits = ((-5,5),(0,nothing)), xlabel = "X", ylabel = "Counts", xticks = -10:2:10)
hist!(randn(10000), bins = -10:0.2:10)
hist!(1.2 .* randn(8000) .+ 2, bins = -10:0.2:10)
hist!(0.5.*randn(2000) .- 3, bins = -10:0.2:10)
fig

# You can also add the LEGEND logo instead of the Juleana logo by calling `legend_logo = true`

LegendMakie.add_watermarks!(legend_logo = true)


# Let us now create a composite plot. We do so by creating a `Makie.GridLayout`
# and adding an `Makie.Axis` in that grid layout:

#md Random.seed!(123) # hide
fig = Figure(size = (600,400))
g = GridLayout(fig[1,1])
ax = Axis(g[1,1], limits = ((-5,5),(0,nothing)), xlabel = "X", ylabel = "Counts", xticks = -10:2:10)
hist!(randn(10000), bins = -10:0.2:10)
hist!(1.2 .* randn(8000) .+ 2, bins = -10:0.2:10)
hist!(0.5.*randn(2000) .- 3, bins = -10:0.2:10)
LegendMakie.add_watermarks!()

# We can also add a second plot to the existing one by creating a new `Makie.Axis`
# and linking the `x`-axes and setting the `rowgap!` to `0`

ax.xticklabelsize = 0
ax.xticksize = 0
ax.xlabel = ""

ax2 = Axis(g[2,1], limits = ((-5,5),(0,nothing)), xlabel = "X", ylabel = "Counts", xticks = -10:2:10, yticks = 0:200:600)
hist!(randn(10000) .+ 0.5, bins = -10:0.2:10)
hist!(1.2.*randn(2000) .- 2, bins = -10:0.2:10)
hist!(0.5.*randn(4000) .+ 2.5, bins = -10:0.2:10)
linkxaxes!(ax,ax2)
rowgap!(g,0)
fig