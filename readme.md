# MarketDataFeeds.jl

A lightweight, easily extensible interface to a range of financial data feeds (Polygon.io, IBKR WebClient API).

You may find some examples in [test/runtests.jl](test/runtests.jl).

If you are interested in a [NGINX](https://www.nginx.com) proxy to IBKR WebClient (to peacefully enforce the pacing limits), take a look at a config generator [make-proxy.jl](ibkr-proxy/make-proxy.jl).

## Historical Market Data Retrieval

<a id='MarketDataFeeds.aggregates' href='#MarketDataFeeds.aggregates'>#</a>
**`MarketDataFeeds.aggregates`** &mdash; *Function*.

```julia
aggregates(source="POLYGON"; <keyword arguments>)
```

Get aggregate bars for an instrument over a given date range in custom time window sizes from given data source.

Return a tuple of series attributes and a matrix where bars correspond to rows, respectively. 

Keyword arguments generally correspond to request parameters for respective data providers.

**Data Sources**

  * `:POLYGON`: polygon.io REST API; requires `apiKey` (`POLYGON_API_KEY` environment var by default). For keyword arguments, see [polygon.io's docs](https://polygon.io/docs/stocks/get_v2_aggs_ticker__stocksticker__range__multiplier___timespan___from___to),
  * `:IBKR`: ibkr.com WebClient API. For keyword arguments, see [IBKR docs](https://www.interactivebrokers.com/api/doc.html#tag/Market-Data/paths/~1hmds~1history/get).

<a id='MarketDataFeeds.aggregates_h5' href='#MarketDataFeeds.aggregates_h5'>#</a>
**`MarketDataFeeds.aggregates_h5`** &mdash; *Function*.

```julia
aggregates_h5(source=Val(:POLYGON); path, <keyword arguments>)
```

Get aggregate bars for an instrument from a given data source, and save the result with associated metadata as an attributed HDF5 file.

Reduces to a call to [`aggregates`](#MarketDataFeeds.aggregates).

Provide keyword argument `path` for the file name. Other keyword arguments are passed to [`aggregates`](#MarketDataFeeds.aggregates).

<a id='MarketDataFeeds.sync!' href='#MarketDataFeeds.sync!'>#</a>
**`MarketDataFeeds.sync!`** &mdash; *Function*.

Update HDF5 files with aggregates in `paths` (either a file or a directory) up to time `to`.

Sync a HDF5 file with aggregates up to time `to`.

**Pro tip:** Data synchronization agents are provided in [agents/aggregates_sync](agents/aggregates_sync).

<a id='MarketDataFeeds.change_provider!' href='#MarketDataFeeds.change_provider!'>#</a>
**`MarketDataFeeds.change_provider!`** &mdash; *Function*.

```julia
change_provider!(source="IBKR", paths; <keyword arguments>)
```

Change the data feed of market data stores in `paths` (a directory, a vector of paths, or a path) to `source`. The original group `bars` will be replaced by a derived view; file's metadata will be updated accordingly (special care has to be taken with timespan conversion - see `IBKR_PERIODS`, `POLYGON_PERIODS`). 

Reduces to `_change_provider`.

## Market Snapshots

<a id='MarketDataFeeds.snapshot' href='#MarketDataFeeds.snapshot'>#</a>
**`MarketDataFeeds.snapshot`** &mdash; *Function*.

```julia
snapshot(source="IBKR"; <keyword arguments>)
```

Get instantaneous market snapshot.

Keyword arguments generally correspond to request parameters for respective data providers.

**Data Sources**

  * `:IBKR`: ibkr.com WebClient API. For keyword arguments, see [IBKR docs](https://www.interactivebrokers.com/api/doc.html#tag/Market-Data/paths/~1md~1snapshot/get).