module MarketDataFeeds

using Reexport

import HTTP, JSON
@reexport using Dates
@reexport import HDF5
using Random

# dictionary <datafeed> => [<minute, hour, day, week, month>]
const BARS = Dict{Val, Vector{String}}()

# if HTTP 429 err, retry request to POLYGON REST API
include("retries.jl")
# time format conversions
include("times.jl")
# retrieve aggregates
include("aggregates.jl")
export aggregates
# market snapshots
include("snapshots.jl")
export snapshot
# retrieve and output aggregates in HDF5 format
include("aggregates_h5.jl")
export aggregates_h5
# HDF5 I/O and filters
include("hdf5.jl")
export filter_times
# append new aggregates
include("sync.jl")
export sync!
# change aggregates provider 
include("change_provider.jl")
export change_provider!

# x -> Val(Symbol(x))
@inline @generated function val(v)::Val
    if v == Symbol; :(Val(v))
    elseif v <: AbstractString; :(Val(Symbol(v)))
    elseif v <: Val; :(v) end
end

end
