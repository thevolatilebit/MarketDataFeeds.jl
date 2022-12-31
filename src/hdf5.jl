# implement HDF5 dataset I/O

"Save aggregates with associated metadata as a HDF5 dataset."
function create_dataset(path::String, attributes::NamedTuple, data::Matrix{Float64};
    chunk_length::Int=10000, shuffle::Bool=true, deflate::Int=5, sync::Bool=true, _...)

    isempty(data) && @error "creating empty dataset is forbidden"

    chunk_length::Int

    HDF5.h5open(path, "w") do f
        # calcuate chunk length
        chunk_length = sync ? chunk_length : min(chunk_length, size(data, 1))
        
        # create dataset, write data
        ds = HDF5.create_dataset(
            f, "bars", HDF5.datatype(Float64),
            HDF5.dataspace(size(data); max_dims=(sync ? -1 : size(data, 1), size(data, 2)));
            chunk=(chunk_length, size(data, 2)), shuffle, deflate
        )
        ds[:, :] = data

        # write attributes
        foreach(keys(attributes)) do p
            HDF5.write_attribute(f, string(p), getproperty(attributes, p))
        end
        HDF5.write_attribute(f, "sync", sync)
    end
end

"Append aggregates to a HDF5 dataset."
function append_dataset! end

function append_dataset!(path::String, data::Matrix{Float64})
    HDF5.h5open(path, "r+") do f
        append_dataset!(f, data)
    end
end

function append_dataset!(f::HDF5.File, data::Matrix{Float64})
    ds = f["bars"]

    if !isempty(data)
        # find last timestamp of the dataset
        t_index::Int = findfirst(==("t"), HDF5.read_attribute(f, "fields"))
        last::Float64 = ds[end, t_index]

        # find successor timestamp
        successor_index = findfirst(x -> data[x, t_index] > last, 1:size(data, 1))
        if !isnothing(successor_index)
            data = @view data[successor_index:end, :]
            HDF5.set_extent_dims(ds, HDF5.get_extent_dims(ds)[1] .+ (size(data, 1), 0))
            ds[(end-size(data, 1)+1):end, :] = data
            HDF5.delete_attribute(f, "to"); HDF5.write_attribute(f, "to", ds[end, t_index])
        end
    end

    f
end

"""
    filter_times(path_new, path; from, to)
Filter out bars outside of the `(from, to)` range."
"""
function filter_times(path_new::String, path::String; from::Real, to::Real,
    chunk_length::Int=10000, shuffle::Bool=true, deflate::Int=5, sync::Bool=false, _...)

    chunk_length::Int

    # open existing dataset
    HDF5.h5open(path, "r") do f
        ds = f["bars"]
        local t_index::Int = findfirst(==("t"), HDF5.read_attribute(f, "fields"))

        # find first, last entry
        local first::Int = searchsortedfirst(1:HDF5.get_extent_dims(ds)[1][1], from, lt=(x,y)->(ds[x, t_index]<y))
        local last::Int = searchsortedlast(1:HDF5.get_extent_dims(ds)[1][1], to, lt=(y,x)->(y<ds[x, t_index]))

        HDF5.h5open(path_new, "w") do f_new
            # calcuate chunk length
            chunk_length = sync ? chunk_length : min(chunk_length, size(last-first+1, 1))
            # create dataset
            ds_new = HDF5.create_dataset(
                f_new, "bars", HDF5.datatype(Float64),
                HDF5.dataspace(
                    (last-first+1, HDF5.get_extent_dims(ds)[1][2]);
                    max_dims=(sync ? -1 : last-first+1, HDF5.get_extent_dims(ds)[2][2])
                );
                chunk=(chunk_length, HDF5.get_extent_dims(ds)[1][2]), shuffle, deflate
            )

            # write subset
            for (i, i_) in enumerate(first:last)
                ds_new[i, :] = ds[i_, :]
            end

            # write attributes
            for k in keys(HDF5.attributes(f))
                HDF5.write_attribute(f_new, k, HDF5.read_attribute(f, k))
            end

            # update attributes "from", "to", "sync"
            HDF5.delete_attribute.(Ref(f_new), ["from", "to", "sync"])
            HDF5.write_attribute(f_new, "from", (last-first+1 > 0) ? ds_new[1, t_index] : NaN)
            HDF5.write_attribute(f_new, "to", (last-first+1 > 0) ? ds_new[end, t_index] : NaN)
            HDF5.write_attribute(f_new, "sync", sync)
        end
    end
end