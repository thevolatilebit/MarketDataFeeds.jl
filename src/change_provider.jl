# change data provider: update data format, fields

function cat_timespan(multiplier::Int, timespan::AbstractString)
    string(multiplier, convert_period(Val(:POLYGON), Val(:IBKR), timespan)) |> fix_timeformat
end

"""
    change_provider!(source="IBKR", paths; <keyword arguments>)
Change the feed of market data stores in `paths` (a path or a vector of paths, incl. directories) to `source`. The original group `bars` will be replaced by a view into it. File's metadata will be updated accordingly (special care has to be taken with timespan conversion - see `IBKR_PERIODS`, `POLYGON_PERIODS`). 

Reduces to `_change_provider`(@ref).
"""
change_provider!(paths; kwargs...) = change_provider!(Val(:IBKR), paths; kwargs...)
change_provider!(source::Union{String, Symbol}, paths; kwargs...) = change_provider!(val(source), paths; kwargs...)

function change_provider!(to::Val{:IBKR}, paths="."; conids::Dict, outsideRth::Bool=true,)
    for path in get_object_paths(paths)
        HDF5.h5open(path, "r+") do f
            from = HDF5.read_attribute(f, "feed")
            _change_provider(val(from), to; f, conids, outsideRth)
        end
    end
end

_change_provider(::Val{T}, ::Val{T}; f, _...) where T = ("same"; f)

function _change_provider(::Val{:POLYGON}, ::Val{:IBKR}; f::HDF5.File, chunk_length::Int=10000,
    shuffle::Bool=true, deflate::Int=5, sync::Bool=true, outsideRth::Bool=true, conids::Dict)
    
    # if already in IBKR format, return
    if !haskey(conids, HDF5.read_attribute(f, "ticker"))
        @warn "conid for entry $(HDF5.read_attribute(f, "ticker")) not found; skipping conversion"
        return f
    end

    # get bar size
    bar = convert_period(Val(:POLYGON), Val(:IBKR), HDF5.read_attribute(f, "timespan"))
    if !haskey(IBKR_PERIODS, bar)
        @warn "period for bar $bar not found"
    end

    # extract fields
    fields = indexin(IBKR_FIELDS, HDF5.read_attribute(f, "fields"))
    data = Matrix(f["bars"][]); data_subview = @view data[:, fields]
    # delete dataset
    HDF5.delete_object(f, "bars")
   
    # write backup data

    ds = HDF5.create_dataset(
        f, "bars", HDF5.datatype(Float64),
        HDF5.dataspace(size(data_subview); max_dims=(sync ? -1 : size(data_subview, 1), size(data_subview, 2)));
        chunk=(chunk_length, size(data_subview, 2)), shuffle, deflate
    )
    ds[:, :] = data_subview

    # update attributes    
    HDF5.delete_attribute.(Ref(f), ("feed", "timespan", "fields"))
    HDF5.write_attribute(f, "bar", bar); HDF5.write_attribute(f, "feed", "IBKR")
    HDF5.write_attribute(f, "outsideRth", outsideRth)
    HDF5.write_attribute(f, "conid", conids[HDF5.read_attribute(f, "ticker")])
    HDF5.write_attribute(f, "fields", IBKR_FIELDS)
    HDF5.write_attribute(f, "period", IBKR_PERIODS[bar])

    f
end