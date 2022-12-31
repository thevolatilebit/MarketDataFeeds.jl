"If calling `ex` results in a HTTP error 429, retry the call after `delay`, for a maximum of `n` retries."
macro retry(ex, delay=1.5, n=4)
    # set retries kw argument in HTTP.get to 0
    if Meta.isexpr(ex.args[1], :parameters)
        filter!(x -> !isexpr(x, :kw), ex.args[1].args)
    end
    filter!(x -> !Meta.isexpr(x, :kw), ex.args[1].args)

    push!(ex.args, Expr(:kw, :retries, 0))

    quote
        n_retries = Ref(0)
        f = () -> try $(esc(ex))
        catch e
            if (e isa HTTP.Exceptions.StatusError) && (e.status == 429) && (n_retries[] <= $(esc(n)))
                # too many request, sleep and then retry
                sleep($(esc(delay))); n_retries[] += 1; f()
            else rethrow() end
        end

        retry(f, delays=Base.ExponentialBackOff(n=$(esc(n))))()
    end
end
