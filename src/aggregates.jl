# Get aggregate bars for an instrument over a given date range in custom time window sizes.

"""
    aggregates(source="POLYGON"; <keyword arguments>)
Get aggregate bars for an instrument over a given date range in custom time window sizes from given data source.

Return a tuple of series attributes and a matrix where bars correspond to rows, respectively. 

Keyword arguments generally correspond to request parameters for respective data providers.

# Data Sources
 - `:POLYGON`: polygon.io REST API; requires `apiKey` (`POLYGON_API_KEY` environment var by default). For keyword arguments, see [polygon.io's docs](https://polygon.io/docs/stocks/get_v2_aggs_ticker__stocksticker__range__multiplier___timespan___from___to)
 - `:IBKR`: IBKR WebClient API; for keyword arguments, see [IBKR docs](https://www.interactivebrokers.com/api/doc.html#tag/Market-Data/paths/~1hmds~1history/get)
"""
aggregates(; kwargs...) = aggregates(Val(:POLYGON); kwargs...)
aggregates(source::Union{String, Symbol}; kwargs...) = aggregates(val(source); kwargs...)

## implement Polygon.io REST API queries for bar aggregates
const POLYGON = "https://api.polygon.io"
const POLYGON_LIMIT_AGGREGATES = 50000
const AGGREGATES_FIELDS = ["v", "c", "o", "vw", "t", "l", "h", "n"]

# polygon bars
push!(BARS, Val(:POLYGON) => ["minute", "hour", "day", "week", "month"])

"If no trade took place, add an `n` field equal to zero, and set `vw` equal to `c`."
@inline function fix!(d::Dict)
    if !haskey(d, "n")
        d["n"] = 0; d["vw"] = d["c"]
    end
end

# See https://polygon.io/docs/stocks/get_v2_aggs_ticker__stocksticker__range__multiplier___timespan___from___to.
function aggregates(::Val{:POLYGON}; ticker::String, multiplier::Int=1, timespan::String="minute",
    from::Union{TimeType, Real}, to::Union{TimeType, Real}=now(UTC),
    adjusted::Bool=true, sort::String="asc", limit::Int=POLYGON_LIMIT_AGGREGATES,
    apiKey=ENV["POLYGON_API_KEY"], _...)

    # convert to milliseconds since unix epoch
    from_str::String = format_time(Val(:POLYGON), from)
    to_str::String = format_time(Val(:POLYGON), to)

    # construct REST API request
    request::String = """
        /v2/aggs/ticker/$ticker/range/$multiplier/$timespan/$from_str/$to_str\
        ?adjusted=$adjusted&sort=$sort&limit=$limit\
        &apiKey=$apiKey\
    """

    # see @retry
    # retry in the next minute
    response = @retry HTTP.get(POLYGON * request) 61-second(now())
    body::Dict = JSON.parse(String(response.body))

    if body["resultsCount"] == 0
        # no results
        attributes::NamedTuple = (; source=:POLYGON,
            ticker, multiplier, timespan,
            from=NaN, to=NaN, adjusted, fields=String[])

        attributes, Matrix{Float64}(undef, 0, 0)
    else
        fields = AGGREGATES_FIELDS
        # cat into a matrix, get attributes
        itr = ((fix!(r); reshape(Float64[r[k] for k in fields], 1, :)) for r in body["results"])
        bars::Matrix{Float64} = vcat(itr...)

        t_index::Int = findfirst(==("t"), fields)
        attributes = (; feed="POLYGON", 
            ticker, multiplier, timespan,
            from=bars[begin, t_index], to=bars[end, t_index], 
            fields)
        
        if (timestamps_estimate(from, to, timespan, multiplier) > limit) &&
                (body["resultsCount"] == limit)
            # if number of timestamps exceeds limit
            attributes_, bars_ = aggregates(Val(:POLYGON);
                ticker, multiplier, timespan,
                from=bars[end, t_index], to,
                adjusted, sort, limit, apiKey)

            if !isempty(bars_)
                t_index_::Int = findfirst(==("t"), attributes_.fields)
                successor_index = findfirst(x -> bars_[x, t_index_] > attributes.to, 1:size(bars_, 1))
                if !isnothing(successor_index)
                    # permute columns (fix fields order)
                    permute_cols!(bars_, attributes_.fields, attributes.fields)
                    bars = vcat(bars, @view bars_[successor_index:end, :])
                    attributes.to = attributes_.to
                end
            end
        end

        return attributes, bars
    end
end

## implement IBKR WebClient API history market data queries
const IBKR_FIELDS = ["t", "o", "h", "l", "c", "v"]
const IBKR_PERIODS = Dict("d" => "2m")

# IBKR bars
push!(BARS, Val(:IBKR) => ["min", "h", "d", "w", "m"])

"Ensure correct IBKR period and bar string format; turn `1<bar>` into `<bar>`"
function fix_timeformat(s::AbstractString)
    m = match(r"(?<multiplier>\d*)(?<timespan>\w*)", s)
    multiplier, timespan = m["multiplier"], m["timespan"]

    multiplier == "1" ? timespan : s
end

# handle initial empty response
struct EmptyBodyException <: Exception end

# See https://www.interactivebrokers.com/api/doc.html#tag/Market-Data/paths/~1hmds~1history/get
function aggregates(::Val{:IBKR}; ibkr::AbstractString=ENV["IBKR_HOST"],
    conid::String, period::String, bar::String, outsideRth::Bool=true, add_period::Bool=false, _...)

    # fix time format
    period, bar = fix_timeformat.((period, bar))

    # construct WebClient API request
    request::String = "/hmds/history?conid=$conid&period=$period&bar=$bar&outsideRth=$outsideRth"
    # retry after initial empty response
    get_body = () -> (response = HTTP.get(ibkr * request); JSON.parse(String(response.body)))
    body::Dict = try 
        # call request multiple times until data is returned
        delays = Base.ExponentialBackOff(n=5, first_delay=0.1, factor=2, max_delay=2)
        r = retry(; delays, check=(_, e) -> e isa EmptyBodyException) do
            body = get_body()
            # check if body is non-empty
            !haskey(body, "points") && throw(EmptyBodyException())

            body
        end

        r()
    # otherwise return incomplete response
    catch; get_body() end

    !haskey(body, "points") && println(body)
    if body["points"] == 0
        # no results
        attributes::NamedTuple = (; source=:IBKR,
            conid, bar, outsideRth, 
            from=NaN, to=NaN, fields=String[])

        attributes, Matrix{Float64}(undef, 0, 0)
    else
        fields = IBKR_FIELDS
        # cat into a matrix, get attributes
        itr = (reshape(Float64[r[k] for k in fields], 1, :) for r in body["data"])
        bars::Matrix{Float64} = vcat(itr...)

        t_index::Int = findfirst(==("t"), fields)
        attributes = (; feed="IBKR", 
            conid, bar, fields, outsideRth,
            from=bars[begin, t_index], to=bars[end, t_index]
        )

        if add_period
            if haskey(IBKR_PERIODS, bar)
                attributes = (; attributes, period=IBKR_PERIODS[bar])
            else @warn "period for bar $bar not found, period will not be included in attributes" end
        end

        return attributes, bars
    end
end
