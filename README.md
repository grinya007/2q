# 2q eviction algorithm
check out it's efficiency
```
git clone https://github.com/grinya007/2q.git
cd 2q
zcat ids.gz | ./test_ch.pl
```

with max size of 2000 entries it does:
```
worked out 1000000 keys
        hit rate:       72.689 %
        memory:         2.828 Mb
        time:           2.767 s
```
Cache::LRU with everything else being equal does:
```
worked out 1000000 keys
        hit rate:       64.762 %
        memory:         3.547 Mb
        time:           2.998 s
```
