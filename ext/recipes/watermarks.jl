# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

function LegendMakie.add_legend_logo!(args...; kwargs...)
    LegendMakie.add_logo!(args...; logofile = LegendMakie.LegendLogo, textcolor = LegendMakie.DeepCove, kwargs...)
end

function LegendMakie.add_juleana_logo!(args...; kwargs...)
    LegendMakie.add_logo!(args...; logofile = LegendMakie.JuleanaSimple, textcolor = :black, kwargs...)
end

LegendMakie.add_logo!(; kwargs...) = LegendMakie.add_logo!(Makie.current_figure(), Makie.current_axis(); kwargs...)

function LegendMakie.add_logo!(fig::Makie.Figure, ax; fontsize = 18, position = "outer right", textcolor = :black, logofile = LegendMakie.JuleanaSimple, show_date = true)

    
    # Optimized for 13.5pt 
    refsize = 13.5
        
    # modify size using fontsize
    font_scale = fontsize/refsize * 0.032
        
    figwidth, figheight = fig.scene.viewport[].widths
    axleft, axbot = ax.scene.viewport[].origin
    axright, axtop = ax.scene.viewport[].origin .+ ax.scene.viewport[].widths

    logo = FileIO.load(logofile)
    logowidth, logoheight = size(logo) .* font_scale
    legend_suffix = (logofile == LegendMakie.LegendLogo ? "-200" : "") * 
        ifelse(show_date, " ⋅ " * Format.format("{:02d}-{:04d}", Dates.month(Dates.today()), Dates.year(Dates.today())), "")

    if position == "outer right"
        img = Makie.image!(fig.scene, Makie.rot180(logo))
        Makie.scale!(img, font_scale, font_scale)
        Makie.translate!(img, (axright, axtop - logoheight))

        Makie.text!(fig.scene, legend_suffix, 
            position = ((axright + fontsize / refsize), (axtop - logoheight)), 
            color = textcolor, fontsize = fontsize, font = :regular, rotation = 1.5π
        )
    elseif position == "outer top"
        img = Makie.image!(fig.scene, Makie.rotr90(logo))
        Makie.scale!(img, font_scale, font_scale)
        Makie.translate!(img, (axleft, axtop))

        Makie.text!(fig.scene, legend_suffix, 
            position = ((axleft + logoheight), (axtop + fontsize / refsize)), 
            color = textcolor, fontsize = fontsize, font = :regular
        )
    else
        throw(ArgumentError("Position $(position) is invalid. Please choose `outer top` or `outer right`."))
    end
    fig
end

LegendMakie.add_text!(text::AbstractString) = LegendMakie.add_text!(Makie.current_figure(), Makie.current_axis(), text)

function LegendMakie.add_text!(fig::Makie.Figure, ax, text::AbstractString)
    axright, axtop = ax.scene.viewport[].origin .+ ax.scene.viewport[].widths
    Makie.text!(fig.scene, text, font = :bold,
        color = :red, position = (axright, axtop), align = (:right, :bottom))
    fig
end

LegendMakie.add_production!(prodname::AbstractString; kwargs...) = LegendMakie.add_production!(Makie.current_figure(), Makie.current_axis(), prodname; kwargs...)

function LegendMakie.add_production!(fig::Makie.Figure, ax, prodname::AbstractString; fontsize::Real = 7)
    axright, axtop = ax.scene.viewport[].origin .+ ax.scene.viewport[].widths .* 0.995
    Makie.text!(fig.scene, prodname; fontsize, position = (axright, axtop), align = (:right, :top))
    fig
end

LegendMakie.add_watermarks!(; kwargs...) = LegendMakie.add_watermarks!(Makie.current_figure(), Makie.current_axis(); kwargs...)

function LegendMakie.add_watermarks!(fig::Makie.Figure, ax;
        legend_logo::Bool = false, juleana_logo::Bool = true, show_date::Bool = true,
        position::String = "outer right",
        preliminary::Bool = true, approved::Bool = false, final::Bool = false, production::Bool = true,
        kwargs...
    )
    if legend_logo
        LegendMakie.add_legend_logo!(fig, ax; position, show_date)
    elseif juleana_logo
        LegendMakie.add_juleana_logo!(fig, ax; position, show_date)
    end

    if !final && preliminary
        LegendMakie.add_text!(fig, ax, "PRELIMINARY")
    elseif !final && !approved
        LegendMakie.add_text!(fig, ax, "INTERNAL USE ONLY")
    end

    if production && haskey(ENV, "LEGEND_DATA_CONFIG")
        prodname = basename(dirname(last(split(ENV["LEGEND_DATA_CONFIG"], ":"))))
        LegendMakie.add_production!(fig, ax, prodname)
    end

    fig
end