# Return market snapshot

"""
    snapshot(source="IBKR"; <keyword arguments>)
Get instantaneous market snapshot.

Keyword arguments generally correspond to request parameters for respective data providers.

# Data Sources
 - `:IBKR`: ibkr.com WebClient API. For keyword arguments, see [IBKR docs](https://www.interactivebrokers.com/api/doc.html#tag/Market-Data/paths/~1md~1snapshot/get).
"""
snapshot(; kwargs...) = snapshot(Val(:IBKR); kwargs...)
snapshot(source::Union{String, Symbol}; kwargs...) = snapshot(val(source); kwargs...)

struct MissingEntriesError <: Exception end

# see https://www.interactivebrokers.com/api/doc.html#tag/Market-Data/paths/~1hmds~1history/get
function snapshot(::Val{:IBKR}; ibkr::AbstractString=ENV["IBKR_HOST"], conids::Vector, fields::Vector=[])
    conids_join = join(conids, ',')
    fields = string.(fields); fields_join = join(fields, ',')

    request::String = "/md/snapshot?conids=$conids_join&fields=$fields_join"

    # get response
    get_response = () -> begin
        response = @retry HTTP.get(ibkr * request)
        
        JSON.parse(String(response.body))
    end

    try 
        # call request multiple times until data for all conids is returned
        delays = Base.ExponentialBackOff(n=5, first_delay=0.1, factor=2, max_delay=2)
        r = retry(; delays, check=(_, e) -> e isa MissingEntriesError) do
            body = get_response()
            # check if response containts data for all conids
            if length(body) == length(conids) && all(r -> haskey(r, "TimestampBase"), body)
                body
            else throw(MissingEntriesError()) end
        end

        r()
    # otherwise return incomplete response
    catch; get_response() end
end