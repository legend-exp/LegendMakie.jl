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
    font_scale = fontsize/refsize * 0.024pt
        
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
            color = textcolor, fontsize = fontsize, font = :regular, rotation = 270u"°"
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


function LegendMakie.add_watermarks!(;
        legend_logo::Bool = false, juleana_logo::Bool = true, position::String = "outer right",
        preliminary::Bool = true, approved::Bool = false, final::Bool = false,
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

    Makie.current_figure()
end

# function LegendMakie.add_juleana_watermark!(; logo_scale = 0.2, position = :rt)

#     fig = Makie.current_figure()
#     ax = Makie.current_axis()

#     figwidth, figheight = fig.scene.viewport[].widths
#     axleft, axbot = ax.scene.viewport[].origin
#     axwidth, axheight = ax.scene.viewport[].widths
#     axright, axtop = ax.scene.viewport[].origin .+ ax.scene.viewport[].widths

#     juleana = FileIO.load(LegendMakie.JuleanaLogo)
#     _logo_scale = logo_scale * axheight / size(juleana,1)
#     juleanaheight, juleanawidth = size(juleana) .* _logo_scale
#     img = Makie.image!(fig.scene, Makie.rotr90(juleana))
#     Makie.scale!(img, _logo_scale, _logo_scale)
#     space = min(0.03 * axwidth, 0.03 * axheight)

#     (; halign, valign) = Makie.legend_position_to_aligns(position)
#     juleanax = halign == :left   ? axleft + space : axright - juleanawidth - space
#     juleanay = valign == :bottom ? axbot  + space : axtop - juleanaheight - space 
#     Makie.translate!(img, (juleanax, juleanay))

#     fig
# end
