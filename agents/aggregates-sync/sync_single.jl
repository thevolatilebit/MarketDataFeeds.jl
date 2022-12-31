# sync a directory or a file provided in first command line argument
# example: `julia1.8 --project=. -- sync_single.jl directory`
using MarketDataFeeds

println("sync job start at $(now()) \n")
sync!(expanduser(ARGS[1]))
println("sync job end at $(now()) \n")