# sync directories or files listed in `paths.txt` - remove the comments!
# example: `julia1.8 --project=. sync.jl`
using MarketDataFeeds

paths = String[]; if isfile("paths.txt")
    for path in eachline("paths.txt")
        push!(paths, expanduser(path))
    end
end

println("sync job start at $(now()) \n")
sync!(paths)
println("sync job end at $(now()) \n")