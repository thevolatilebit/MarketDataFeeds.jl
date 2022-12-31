using Test 

using MarketDataFeeds
using MarketDataFeeds.HTTP, MarketDataFeeds.JSON

# POLYGON
if haskey(ENV, "POLYGON_API_KEY")
    date_from = today() - Month(2)
    date_to = date_from + Month(1)

    tmp_dir = mktempdir()

    aggregates(; ticker="AAPL", timespan="minute", from=1665791940000)
    aggregates_h5(; path="$tmp_dir/AAPL-d.h5", ticker="AAPL", timespan="minute", from=date_from, to=date_to)

    from, to = HDF5.h5open("$tmp_dir/AAPL-d.h5") do f
        HDF5.read_attribute(f, "from"), HDF5.read_attribute(f, "to")
    end

    sync!("$tmp_dir/AAPL-d.h5")

    HDF5.h5open("$tmp_dir/AAPL-d.h5") do f
        t_index = findfirst(==("t"), HDF5.read_attribute(f, "fields"))
        @test !isnothing(t_index)
        @test f["bars"][][begin, t_index] == HDF5.read_attribute(f, "from") == from
        @test f["bars"][][end, t_index] == HDF5.read_attribute(f, "to")
    end

    filter_times("$tmp_dir/AAPL-d-filtered.h5", "$tmp_dir/AAPL-d.h5"; from, to)

    from_, to_ = HDF5.h5open("$tmp_dir/AAPL-d-filtered.h5") do f
        HDF5.read_attribute(f, "from"), HDF5.read_attribute(f, "to")
    end

    @test from_ == from
    @test to_ == to
else @warn "polygon.io API key not found (`POLYGON_API_KEY` environment variable); skipping test" end

# IBKR
ibkr_status = if haskey(ENV, "IBKR_HOST")
    # check if session is authenticated
    response = HTTP.get(ENV["IBKR_HOST"] * "/tickle")
    body = JSON.parse(String(response.body))
    body["iserver"]["authStatus"]["authenticated"]
else false end

if ibkr_status
    # snapshots
    snapshot(; conids=["5049", "1448477", "3691937", "9705", "4901", "87335484", "6437", "459530964", "10098", "2585769"])

    # aggregates
    period = "5d"
    date_to = datetime2unix(now() - Day(1)) * 1000

    aggregates_h5("IBKR"; path="$tmp_dir/5049-h-1.h5", conid="5049", period, bar="h")

    attributes, data = aggregates("IBKR"; conid="5049", period, bar="h")

    t_ix = indexin(("t",), attributes.fields)[1]
    ixs = filter(x -> data[x, t_ix] <= date_to, 1:size(data, 1))
    data = Matrix(@view data[ixs, :])
    attr_fields = setdiff(keys(attributes), (:to,))
    attributes_ = (; (a => attributes[a] for a in attr_fields)..., to=data[end, t_ix])

    # write subset
    MarketDataFeeds.create_dataset("$tmp_dir/5049-h-2.h5", attributes_, data;)
    
    from, to = HDF5.h5open("$tmp_dir/5049-h-2.h5") do f
        HDF5.read_attribute(f, "from"), HDF5.read_attribute(f, "to")
    end

    # append latest data
    sync!("$tmp_dir/5049-h-2.h5")

    HDF5.h5open("$tmp_dir/5049-h-2.h5") do f
        t_index = findfirst(==("t"), HDF5.read_attribute(f, "fields"))
        @test !isnothing(t_index)
        @test f["bars"][][begin, t_index] == HDF5.read_attribute(f, "from") == from
        @test f["bars"][][end, t_index] == HDF5.read_attribute(f, "to")
    end

    # filter bars
    filter_times("$tmp_dir/5049-h-3.h5", "$tmp_dir/5049-h-2.h5"; from, to)

    from_, to_ = HDF5.h5open("$tmp_dir/5049-h-3.h5") do f
        HDF5.read_attribute(f, "from"), HDF5.read_attribute(f, "to")
    end

    @test from_ == from
    @test to_ == to

    # convert between providers
    date_from = today() - Month(2)
    date_to = date_from + Month(1)

    aggregates_h5(; path="$tmp_dir/AAPL-d-1.h5", ticker="AAPL", timespan="day", from=date_from, to=date_to)

    to = HDF5.h5open(f -> HDF5.read_attribute(f, "to"), "$tmp_dir/AAPL-d-1.h5")

    l = readlines("conids.txt")
    conids = Dict((Pair(split(l, ';')...) for l in l))

    change_provider!("$tmp_dir/AAPL-d-1.h5"; conids)
    sync!("$tmp_dir/AAPL-d-1.h5")

    to_ = HDF5.h5open(f -> HDF5.read_attribute(f, "to"), "$tmp_dir/AAPL-d-1.h5")

    # test if new data was fetched
    @test to_ > to
else @warn "`IBKR_HOST` environment variable not found or IBKR session not authenticated; skipping tests" end