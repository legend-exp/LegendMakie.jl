# This file is a part of LegendMakie.jl, licensed under the MIT License (MIT).

module LegendMakieRadiationDetectorSignalsExt

import LegendMakie
using MakieCore

using RadiationDetectorSignals: RDWaveform, ArrayOfRDWaveforms


function LegendMakie.lplot(wf::RDWaveform)
    # ...
end

function LegendMakie.lplot(wf::ArrayOfRDWaveforms)
    # ...
end


function LegendMakie.some_custom_waveform_plot(wf::RDWaveform)
    # ...
end

end # module LegendMakieRadiationDetectorSignalsExt
