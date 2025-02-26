# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieMeasurementsExt

    import LegendMakie

    import LaTeXStrings
    import Makie
    import Measurements
    import Unitful

    import LegendMakie: pt, aoecorrectionplot!, energycalibrationplot!

    # function to compose labels when errorbars are scaled
    function label_errscaling(xerrscaling::Real, yerrscaling::Real)
        result = String[]
        xerrscaling != 1 && push!(result, "x-Error ×$(xerrscaling)")
        yerrscaling != 1 && push!(result, "y-Error ×$(yerrscaling)")
        isempty(result) ? "" : " ($(join(result,", ")))"
    end


    Makie.@recipe(AoECorrectionPlot, report) do scene
        Makie.Attributes(
            color = (LegendMakie.AchatBlue,0.5),
            markercolor = :black
        )
    end
    
    # Needed for creatings legend using Makie recipes
    # https://discourse.julialang.org/t/makie-defining-legend-output-for-a-makie-recipe/121567
    function Makie.get_plots(p::AoECorrectionPlot)
        return p.plots
    end
    
    function Makie.plot!(p::AoECorrectionPlot{<:Tuple{NamedTuple{(:par, :f_fit, :x, :y, :gof, :e_unit, :label_y, :label_fit)}}})
        report = p.report[]
        Makie.lines!(p, 0:1:3000, report.f_fit ∘ Measurements.value, color = p.color, label = LaTeXStrings.latexstring("\\fontfamily{Roboto}" * report.label_fit))
        Makie.errorbars!(p, report.x, Measurements.value.(report.y), Measurements.uncertainty.(report.y), color = p.markercolor)
        Makie.scatter!(p, report.x, Measurements.value.(report.y), color = p.markercolor, label = "Compton band fits: Gaussian $(report.label_y)(A/E)")
        p
    end


    Makie.@recipe(EnergyCalibrationPlot, report, additional_pts) do scene
        Makie.Attributes(
            color = LegendMakie.AchatBlue,
            plot_ribbon = true,
            xerrscaling = 1,
            yerrscaling = 1
        )
    end

    # Needed for creatings legend using Makie recipes
    # https://discourse.julialang.org/t/makie-defining-legend-output-for-a-makie-recipe/121567
    function Makie.get_plots(p::EnergyCalibrationPlot)
        return p.plots
    end
    
    function Makie.plot!(p::EnergyCalibrationPlot{<:Tuple{<:NamedTuple{(:par, :f_fit, :x, :y, :gof)}, <:NamedTuple}})
        
        report = p.report[]
        additional_pts = p.additional_pts[]
        xerrscaling = p.xerrscaling[]
        yerrscaling = p.yerrscaling[]

        # plot fit
        xfit = 0:1:1.2*Measurements.value(maximum(report.x))
        yfit = report.f_fit.(xfit)
        yfit_m = Measurements.value.(yfit)
        Makie.lines!(xfit, yfit_m, label = "Best Fit" * (!isempty(report.gof) ? " (p = $(round(report.gof.pvalue, digits=2))| χ²/ndf = $(round(report.gof.chi2min, digits=2)) / $(report.gof.dof))" : ""), color = p.color)
        if p.plot_ribbon[]
            Δyfit = Measurements.uncertainty.(yfit)
            Makie.band!(xfit, yfit_m .- Δyfit, yfit_m .+ Δyfit, color = (p.color[], 0.2))
        end
        
        # scatter points with error bars
        xvalues = Measurements.value.(report.x)
        yvalues = Measurements.value.(report.y)
        Makie.errorbars!(p, xvalues, yvalues, Measurements.uncertainty.(report.x) .* xerrscaling, direction = :x, color = :black)
        Makie.errorbars!(p, xvalues, yvalues, Measurements.uncertainty.(report.y) .* yerrscaling, color = :black)
        Makie.scatter!(p, xvalues, yvalues, marker = :circle, color = :black, label = "Data" * label_errscaling(xerrscaling, yerrscaling))
        
        # plot additional points
        if !isempty(additional_pts)
            xvalues = Measurements.value.(additional_pts.x)
            yvalues = Measurements.value.(additional_pts.y)
            Makie.errorbars!(p, xvalues, yvalues, Measurements.uncertainty.(additional_pts.x) .* xerrscaling, direction = :x, color = :black)
            Makie.errorbars!(p, xvalues, yvalues, Measurements.uncertainty.(additional_pts.y) .* yerrscaling, color = :black)
            Makie.scatter!(p, xvalues, yvalues, marker = :circle, color = :silver, strokewidth = 1, strokecolor = :black, label = "Data not used for fit" * label_errscaling(xerrscaling, yerrscaling))
        end

        p
    end

end