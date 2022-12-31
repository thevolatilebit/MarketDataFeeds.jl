"Get a list of HDF5 files in the directory tree of a directory (if a path to a HDF5 is given at the input, return that path)."
function get_object_paths(paths)
    paths_::Vector{String} = String[]
    for path in (paths isa String ? [paths] : paths)
        if isfile(path) && HDF5.ishdf5(path)
            push!(paths_, path)
        elseif isdir(path)
            for (dir_path, _, path) in walkdir(path), path in path
                try_path = joinpath(dir_path, path)
                HDF5.ishdf5(try_path) && push!(paths_, try_path)
            end
        end
    end

    paths_
end

"Update HDF5 files with aggregates in `paths` (either a file or a directory) up to time `to`."
function sync!(paths="."; to=now(UTC))
    for path in get_object_paths(paths)
        f = HDF5.h5open(path, "r+")

        try sync!(f; to)
        catch e; @warn "file $path sync errored: $e"
        finally HDF5.close(f)
        end
    end
end

"For a selected data feed, extract options for an aggregate bars query from file's attributes."
aggregate_opts(feed, args...; kwargs...) = aggregate_opts(val(feed), args...; kwargs...)

function aggregate_opts(::Val{:POLYGON}, f::HDF5.File; to=now(UTC), _...)
    ticker, multiplier, timespan = 
        HDF5.read_attribute.(Ref(f), ["ticker", "multiplier", "timespan"])
    last_timestamp::Int = Int(HDF5.read_attribute(f, "to"))

    (; ticker, multiplier, timespan, from=last_timestamp, to)
end

function aggregate_opts(::Val{:IBKR}, f::HDF5.File; _...)
    conid, bar, outsideRth = HDF5.read_attribute.(Ref(f), ["conid", "bar", "outsideRth"])

    period = if "period" in keys(HDF5.attributes(f))
        HDF5.read_attribute(f, "period")
    else
        gap = (now() - unix2datetime(HDF5.read_attribute(f, "to")/1000))
        "$(ceil(Int, gap / Day(1)))d"
    end

    (; conid, bar, outsideRth, period)
end

"Sync a HDF5 file with aggregates up to time `to`."
function sync!(f::HDF5.File; to=now(UTC))
    if HDF5.read_attribute(f, "sync")
        feed = HDF5.read_attribute(f, "feed")

        attributes, data = aggregates(val(feed); aggregate_opts(feed, f; to)...)
        permute_cols!(data, attributes.fields, HDF5.read_attribute(f, "fields"))
        
        append_dataset!(f, data)
    end
end

# fix order of dataset columns
function permute_cols!(data::Matrix{Float64}, new_fields::Vector{String}, fields::Vector{String})
    if !isempty(data)
        indices::Vector{Int} = indexin(fields, new_fields)
        Base.permutecols!!(data, indices)
    end
end