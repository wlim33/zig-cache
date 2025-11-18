
# zig-cache

Small playground of cache eviction strategies implemented in Zig 0.15. Each cache has a focused test suite and the project includes a micro benchmark harness (`src/main.zig`).

## Cache flavors

- `src/basic.zig` – TTL map built on `AutoArrayHashMap` with coarse eviction.
- `src/lru.zig` – doubly linked list + hash map LRU with optional eviction callback.
- `src/fifo.zig` – queue eviction, assignments do not disturb position.
- `src/mru.zig` – inverse of LRU, drops the most recently used entry first.
- `src/random.zig` – random victim cache backed by `AutoArrayHashMap` and a tiny PRNG.
- `src/lfu.zig` – least-frequently-used cache with frequency counters per entry.
- `src/clock.zig` – clock/second-chance cache using the shared linked list nodes.
- `src/TwoQueueCache.zig` – placeholder for the 2Q algorithm.

## Usage

### Run all tests

```sh
zig test src/basic.zig src/lru.zig src/fifo.zig src/mru.zig src/random.zig src/lfu.zig src/clock.zig src/TwoQueueCache.zig
```

### Benchmark the basic LRU

Use CLI flags to override the default `--size 1000 --count 100000`:

```sh
cd /Users/williamlim/Projects/zig-cache/zig-cache
zig run src/main.zig -- --size 2048 --count 250000
```

To sweep multiple combinations in one go:

```sh
cd /Users/williamlim/Projects/zig-cache/zig-cache
for size in 256 512 1024; do
	for count in 100000 200000; do
		zig run src/main.zig -- --size "$size" --count "$count"
	done
done
```

The benchmark seeds its own PRNG and prints hit/miss ratios for each run.
