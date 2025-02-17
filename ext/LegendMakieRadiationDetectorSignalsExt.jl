# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieRadiationDetectorSignalsExt

import LegendMakie
using MakieCore

using RadiationDetectorSignals: RDWaveform, ArrayOfRDWaveforms


function LegendMakie.lmplot(wf::RDWaveform)
    # ...
end

function LegendMakie.lmplot(wf::ArrayOfRDWaveforms)
    # ...
end


function LegendMakie.some_custom_waveform_plot(wf::RDWaveform)
    # ...
end

end # module LegendMakieRadiationDetectorSignalsExt
