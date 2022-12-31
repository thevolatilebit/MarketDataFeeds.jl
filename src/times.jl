# handling bar times

"""
    format_time(provider, time::TimeType)
    format_time(provider, milliseconds::Int)

Given a time object, return a formatted string compatible with the provider.
"""
function format_time end

"Return either a date `yyyy-mm-dd` or the number of milliseconds since unix epoch."
@inline @generated function format_time(::Val{:POLYGON}, time)::String
    if time <: DateTime
        return :(string(floor(Int, 1e3*datetime2unix(time))))
    elseif time <: Date 
        return :(Dates.format(time, "yyyy-mm-dd"))
    elseif time <: Real
        return :(string(floor(Int, time)))
    end
end

@inline @generated function format_time(::Val{:TIMESTAMP}, time)::String
    if time <: DateTime
        return :(string(floor(Int, 1e3*datetime2unix(time))))
    elseif time <: Date 
        return :(format_time(Val("TIMESTAMP"), DateTime(time)))
    elseif time <: Real
        return :(string(floor(Int, time)))
    end
end

const timespan_to_period = Dict{String, Period}(
    "minute" => Minute(1), "hour" => Hour(1), "day" => Day(1),
    "week" => Week(1), "month" => Month(1), "quarter" => Quarter(1), "year" => Year(1)
)

function timestamps_estimate(t1, t2, timespan::String, multiplier::Int)::Int
    t1::DateTime = t1 isa Real ? unix2datetime(floor(Int, t1/1000)) : DateTime(t1)
    t2::DateTime = t2 isa Real ? unix2datetime(ceil(Int, t2/1000)) : DateTime(t2)

    ceil(Int, (t2 - t1) / (multiplier * timespan_to_period[timespan]))
end

"""
    convert_period(from, to, bar)
Convert timespan/bar format between data providers.
"""
function convert_period(from, to, bar::AbstractString)
    from = val(from); to = val(to)
    
    (bar ∈ BARS[to]) ? bar : BARS[to][indexin((bar,), BARS[from])[1]]
end