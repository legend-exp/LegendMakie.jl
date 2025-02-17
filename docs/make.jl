# Use
#
#     DOCUMENTER_DEBUG=true julia --color=yes make.jl local [nonstrict] [fixdoctests]
#
# for local builds.

using Documenter
using LegendMakie

# Doctest setup
DocMeta.setdocmeta!(
    LegendMakie,
    :DocTestSetup,
    :(using LegendMakie);
    recursive=true,
)

makedocs(
    sitename = "LegendMakie",
    modules = [LegendMakie],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        canonical = "https://legend-exp.github.io/LegendMakie.jl/stable/"
    ),
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
        "LICENSE" => "LICENSE.md",
    ],
    doctest = ("fixdoctests" in ARGS) ? :fix : true,
    linkcheck = !("nonstrict" in ARGS),
    warnonly = ("nonstrict" in ARGS),
)

deploydocs(
    repo = "github.com/legend-exp/LegendMakie.jl.git",
    forcepush = true,
    push_preview = true,
)
