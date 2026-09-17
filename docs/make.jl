# Use
#
#     DOCUMENTER_DEBUG=true julia --color=yes make.jl local [nonstrict] [fixdoctests]
#
# for local builds.

using Documenter
using Literate
using LegendMakie

# Doctest setup
DocMeta.setdocmeta!(
    LegendMakie,
    :DocTestSetup,
    :(using LegendMakie);
    recursive=true,
)

function fix_literate_output(content)
    content = replace(content, "EditURL = \"@__REPO_ROOT_URL__/\"" => "")
    return content
end

# Every `*_lit.jl` in these directories becomes a page whose code runs at build time, and a notebook
for gen_content_dir in joinpath.(@__DIR__, "src", ("", "tutorials", "recipes"))
    for tut_lit_fn in filter(fn -> endswith(fn, "_lit.jl"), readdir(gen_content_dir))
        lit_src_fn = joinpath(gen_content_dir, tut_lit_fn)
        tut_basename = tut_lit_fn[1:end-7] # remove "_lit.jl"
        Literate.notebook(lit_src_fn, gen_content_dir, name = tut_basename, documenter = true, credit = true, execute = false)
        Literate.markdown(lit_src_fn, gen_content_dir, name = tut_basename, documenter = true, credit = true, postprocess = fix_literate_output)
    end
end

makedocs(
    sitename = "LegendMakie",
    modules = [LegendMakie],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        canonical = "https://legend-exp.github.io/LegendMakie.jl/stable/",
        size_threshold = nothing, size_threshold_warn = nothing, example_size_threshold = nothing
    ),
    pages = [
        "Home" => "index.md",
        "Tutorials" => [
            "tutorials/basic_tutorial.md",
        ],
        "Plot options" => "plot_options.md",
        "Recipes" => [
            "Histograms" => "recipes/histograms.md",
            "Waveforms and events" => "recipes/waveforms.md",
            "Parameters per detector" => "recipes/parameters.md",
            "Fits, cuts and filter optimization" => "recipes/fits.md",
            "Energy calibration" => "recipes/energy_calibration.md",
            "A/E" => "recipes/aoe.md",
            "LQ" => "recipes/lq.md",
            "SiPM calibration" => "recipes/sipm.md",
        ],
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
