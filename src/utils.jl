# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

# Define LEGEND colors
const DeepCove    = "#1A2A5B"
const AchatBlue   = "#07A9FF"
const DiamondGrey = "#CCCCCC"

# Define additional colors
const ICPCBlue    = "#07A9FF" # AchatBlue
const PPCPurple   = "#BF00BF"
const BEGeOrange  = "#FFA500"
const CoaxGreen   = "#008000"

# Define LEGEND font
const LegendFont = "Roboto"

# Taken from https://docs.makie.org/stable/how-to/match-figure-size-font-sizes-and-dpi
const inch = 96
const pt   = 4/3
const cm   = inch / 2.54

# Define file path for logo files
const LegendLogo        = joinpath(@__DIR__, "logo", "legend_darkblue.png")
const JuleanaLogo       = joinpath(@__DIR__, "logo", "juleana_small.png")
const JuleanaSimple     = joinpath(@__DIR__, "logo", "juleana_simple.png")
