# write aggregates into a hdf5 file

"""
    aggregates_h5(source=Val(:POLYGON); path, <keyword arguments>)
Get aggregate bars for an instrument from a given data source, and save the result with associated metadata as an attributed HDF5 file.

Reduces to a call to [`aggregates`](@ref).

Provide keyword argument `path` for the file name. Other keyword arguments are passed to [`aggregates`](@ref).
"""
aggregates_h5(; kwargs...) = aggregates_h5(Val(:POLYGON); kwargs...)

aggregates_h5(source::Union{String, Symbol}; kwargs...) = aggregates_h5(val(source); kwargs...)

function aggregates_h5(source::Val; path::AbstractString, kwargs...)
    mkpath(dirname(path))
    
    attributes, data = aggregates(source; kwargs...)
 
    create_dataset(path, attributes, data; kwargs...)
end