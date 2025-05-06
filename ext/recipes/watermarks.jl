# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

function LegendMakie.add_legend_logo!(args...; kwargs...)
    LegendMakie.add_logo!(args...; logofile = LegendMakie.LegendLogo, textcolor = LegendMakie.DeepCove, kwargs...)
end

function LegendMakie.add_juleana_logo!(args...; kwargs...)
    LegendMakie.add_logo!(args...; logofile = LegendMakie.JuleanaSimple, textcolor = :black, kwargs...)
end

function LegendMakie.add_logo!(; fontsize = 18, position = "outer right", textcolor = :black, logofile = LegendMakie.JuleanaSimple)

    fig = Makie.current_figure()
    ax = Makie.current_axis()
    
    # Optimized for 13.5pt 
    refsize = 13.5
        
    # modify size using fontsize
    font_scale = fontsize/refsize * 0.032
        
    figwidth, figheight = fig.scene.viewport[].widths
    axleft, axbot = ax.scene.viewport[].origin
    axright, axtop = ax.scene.viewport[].origin .+ ax.scene.viewport[].widths

    logo = FileIO.load(logofile)
    logowidth, logoheight = size(logo) .* font_scale
    legend_suffix = (logofile == LegendMakie.LegendLogo ? "-200" : "") * " ⋅ " * 
        Format.format("{:02d}-{:04d}", Dates.month(Dates.today()), Dates.year(Dates.today()))

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

function LegendMakie.add_text!(text::AbstractString)
    fig = Makie.current_figure()
    ax = Makie.current_axis()
    axright, axtop = ax.scene.viewport[].origin .+ ax.scene.viewport[].widths
    Makie.text!(fig.scene, text, font = :bold,
        color = :red, position = (axright, axtop), align = (:right, :bottom))
    fig
end

function LegendMakie.add_production!(prodname::AbstractString; fontsize::Real = 7)
    fig = Makie.current_figure()
    ax = Makie.current_axis()
    axright, axtop = ax.scene.viewport[].origin .+ ax.scene.viewport[].widths .* 0.995
    Makie.text!(fig.scene, prodname; fontsize, position = (axright, axtop), align = (:right, :top))
    fig
end

function LegendMakie.add_watermarks!(;
        legend_logo::Bool = false, juleana_logo::Bool = true, position::String = "outer right",
        preliminary::Bool = true, approved::Bool = false, final::Bool = false, production::Bool = true,
        kwargs...
    )
    if legend_logo
        LegendMakie.add_legend_logo!(; position)
    elseif juleana_logo
        LegendMakie.add_juleana_logo!(; position)
    end

    if !final && preliminary
        LegendMakie.add_text!("PRELIMINARY")
    elseif !final && !approved
        LegendMakie.add_text!("INTERNAL USE ONLY")
    end

    if production && haskey(ENV, "LEGEND_DATA_CONFIG")
        prodname = basename(dirname(last(split(ENV["LEGEND_DATA_CONFIG"], ":"))))
        LegendMakie.add_production!(prodname)
    end

    Makie.current_figure()
end