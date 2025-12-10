# <<<<<<< OLD CODE from 3816692f2d (2bdc9b336e) - COMMENTED OUT
# # <<<<<<< OLD CODE from 138ec6cc49 (76c36039df) - COMMENTED OUT
# # <!---
# #     MIT License
# # =======
# =======
# cudf 25.12.00 (10 Dec 2025)

### 🚨 Breaking Changes
* Rewrite JNI functions to use `JNI_TRY`/`JNI_CATCH` by @ttnghia in https://github.com/rapidsai/cudf/pull/19053
* Remove compatibility with nvCOMP versions before 5.0 by @vuule in https://github.com/rapidsai/cudf/pull/20140
* Remove DataFrame.apply_chunks, Groupby.apply_grouped by @mroeschke in https://github.com/rapidsai/cudf/pull/20194
* Change .str.starts/endswith with tuple argument to match any pattern instead of pairwise matching by @mroeschke in https://github.com/rapidsai/cudf/pull/20249
* [cudf-polars] CUDA stream by @madsbk in https://github.com/rapidsai/cudf/pull/20154
* Chunked read parquet, prepend index column, and apply deletion vector by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20201
* Zero-copy `hostdevice_vector` on integrated systems by @vuule in https://github.com/rapidsai/cudf/pull/20225
* Use int64_t for the num_rows slot in parquet_reader_options by @wence- in https://github.com/rapidsai/cudf/pull/20256
* Require CUDA 12.2+ by @jakirkham in https://github.com/rapidsai/cudf/pull/20416
* Remove compatibility for CCCL < 3.1 by @bdice in https://github.com/rapidsai/cudf/pull/20468
* Remove deprecated types and APIs by @vuule in https://github.com/rapidsai/cudf/pull/20422
* Support signed integers and decimals in `SUM_WITH_OVERFLOW` groupby by @PointKernel in https://github.com/rapidsai/cudf/pull/19598
* Change groupby-scan COUNT to 1-based results by @davidwendt in https://github.com/rapidsai/cudf/pull/20168
* Change strings::like() pattern parameter from string_scalar to string_view by @davidwendt in https://github.com/rapidsai/cudf/pull/20428
* No-op performance tracking wrappers by @galipremsagar in https://github.com/rapidsai/cudf/pull/20595
### 🐛 Bug Fixes
* Copy `attrs` at correct place in `DataFrame` constructor by @galipremsagar in https://github.com/rapidsai/cudf/pull/20074
* Handle missing nightly runs in pandas tests job by @galipremsagar in https://github.com/rapidsai/cudf/pull/20081
* Fix numpy ufunc for `DataFrame` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20070
* Unproxy few unnecessary testing utilities in pandas by @galipremsagar in https://github.com/rapidsai/cudf/pull/20088
* Fix libcudf groupby benchmarks to not include internal cache by @davidwendt in https://github.com/rapidsai/cudf/pull/20038
* Fix cudf.date_range with non-iso start and end date strings by @mroeschke in https://github.com/rapidsai/cudf/pull/20116
* Fix create_distinct_rows_column to create non-nullable columns by @davidwendt in https://github.com/rapidsai/cudf/pull/20082
* Fix arrow timestamp frequency cases in `cudf.pandas` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20128
* Cast inputs to true division from decimal to float by @Matt711 in https://github.com/rapidsai/cudf/pull/20077
* Handle NVMLError_NotSupported in cudf-polars by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20179
* Fix RMM JNI pinned_fallback_host_memory_resource for CCCL 3.1.0 by @bdice in https://github.com/rapidsai/cudf/pull/20160
* Require passing memory resources to from_libcudf methods by @vyasr in https://github.com/rapidsai/cudf/pull/20171
* Enable hash-groupby for decimal32/64 type and MEAN aggregation by @davidwendt in https://github.com/rapidsai/cudf/pull/20040
* Align decimal dtypes in predicate before conditional join by @Matt711 in https://github.com/rapidsai/cudf/pull/20060
* Change stream_checking_resource_adaptor::do_deallocate to noexcept by @vyasr in https://github.com/rapidsai/cudf/pull/20218
* Deallocation should be noexcept by @bdice in https://github.com/rapidsai/cudf/pull/20219
* Fix a race condition in the decode of delta encoded Parquet columns by @vuule in https://github.com/rapidsai/cudf/pull/20216
* Fix the host-device tdigest offsets by using cuda::std::span by @PointKernel in https://github.com/rapidsai/cudf/pull/20220
* Add `stream` and `mr` arguments to `Column.from_arrow` type stub by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20244
* Pin `deltalake` in cudf-polars-polars-tests CI job by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20255
* Pin ibis-framework<11.0.0 by @Matt711 in https://github.com/rapidsai/cudf/pull/20267
* Add private attributes for `cudf.pandas` proxy objects by @galipremsagar in https://github.com/rapidsai/cudf/pull/20276
* Add Proxy for `SparseAccessor` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20278
* We need this to pacify mypy by @wence- in https://github.com/rapidsai/cudf/pull/20285
* Purge non-empty nulls for the generated lists columns in data generation utility by @ttnghia in https://github.com/rapidsai/cudf/pull/20283
* Fix missing table compatibility check in two_table_comparator constructor by @PointKernel in https://github.com/rapidsai/cudf/pull/20305
* Fix the check for equal `num_cols` across empty parquet sources by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20320
* Add `nans_to_nulls` to `Frame` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20314
* Add support for list type in `get` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20332
* Fix decimal dtype serialization in cudf-polars by @Matt711 in https://github.com/rapidsai/cudf/pull/20300
* Make the `GroupedRollingWindow`expression node reconstructable in cudf-polars by @Matt711 in https://github.com/rapidsai/cudf/pull/20288
* Ensure pylibcudf.Scalar.from_py uses CUDA streams by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20340
* Skip failing cudf-polars test due to hash groupby bug by @Matt711 in https://github.com/rapidsai/cudf/pull/20356
* Support order by keys for order-sensitive scalar aggregations in grouped windows by @Matt711 in https://github.com/rapidsai/cudf/pull/20350
* Honor user-passed stream in slice_strings for scalar inputs by @mroeschke in https://github.com/rapidsai/cudf/pull/20349
* Thread missing streams in column/table view creation to char size calculation by @vyasr in https://github.com/rapidsai/cudf/pull/20351
* Fix missed-sync for `mapping_indices_kernel` in hash-based groupby aggregation by @ttnghia in https://github.com/rapidsai/cudf/pull/20370
* Fix a few SPDX-related issues by @KyleFromNVIDIA in https://github.com/rapidsai/cudf/pull/20364
* Fix a `dtype` bug in column constructor by @galipremsagar in https://github.com/rapidsai/cudf/pull/20384
* Refactor `as_column` dtype parameter calls by @galipremsagar in https://github.com/rapidsai/cudf/pull/20379
* Add CUDA stream to `cudf_polars.Column.deserialize` by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20396
* Add missing CUDA stream to cudf-polars left-semi join by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20398
* Fix various string APIs to work with extension types by @galipremsagar in https://github.com/rapidsai/cudf/pull/20368
* Add parameter validation for `merge` and `MultiIndex.from_frame` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20382
* Fix nvtext::normalize_characters special token case by @davidwendt in https://github.com/rapidsai/cudf/pull/20242
* Fix pinned memory resource `shared_pointer` lifetime in tests. by @bdice in https://github.com/rapidsai/cudf/pull/20407
* Support new `nvcompStatus_t` enum value by @vuule in https://github.com/rapidsai/cudf/pull/20376
* Don't skip blank CSV lines rows after the header in cudf-polars scan_csv by @mroeschke in https://github.com/rapidsai/cudf/pull/20341
* Fix OOB accesses in JSON_CornerCase_Empty test and get_row_array_parent_col_id function by @bdice in https://github.com/rapidsai/cudf/pull/20421
* Change calls to cudaMemcpyToSymbol to cudaMemcpyToSymbolAsync by @davidwendt in https://github.com/rapidsai/cudf/pull/20374
* Do not accelerate `pandas._config.config` by @Matt711 in https://github.com/rapidsai/cudf/pull/20413
* Return timedelta instead of datetime type with std with datetime type with missing values by @mroeschke in https://github.com/rapidsai/cudf/pull/20439
* Disallow non-bool skipna arguments to reduction methods by @mroeschke in https://github.com/rapidsai/cudf/pull/20436
* Fix parquet scans for duckDB PDS-DS by @Matt711 in https://github.com/rapidsai/cudf/pull/20388
* Support `__array_function__` on the proxy array type by @Matt711 in https://github.com/rapidsai/cudf/pull/20419
* Make `memory_usage` and `__sizeof__` proxy attributes and always skip all memory usage tests by @Matt711 in https://github.com/rapidsai/cudf/pull/20425
* Add input validation for `from_records` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20412
* Use computed reduction result type for empty sum and product aggregations by @mroeschke in https://github.com/rapidsai/cudf/pull/20438
* Correct level arg validation for Index.isin, unique by @mroeschke in https://github.com/rapidsai/cudf/pull/20449
* Add private `_grouper` attribute to `DataFrameGroupBy` proxy type by @Matt711 in https://github.com/rapidsai/cudf/pull/20448
* Raise ValueError when indexing with zero step slice by @mroeschke in https://github.com/rapidsai/cudf/pull/20453
* Raise IndexError for float-like indexers in RangeIndex/MultiIndex.__getitem__ by @mroeschke in https://github.com/rapidsai/cudf/pull/20454
* Disallow slice(bool, ...) in DataFrame.loc with MultiIndex by @mroeschke in https://github.com/rapidsai/cudf/pull/20457
* Fix core dump in MemoryCleaner by @res-life in https://github.com/rapidsai/cudf/pull/19872
* Disallow multiple ellipse values in loc/iloc indexing by @mroeschke in https://github.com/rapidsai/cudf/pull/20456
* Fix `scan` operations for `string` columns by @galipremsagar in https://github.com/rapidsai/cudf/pull/20460
* Fix UTF8 data generator in libcudf benchmarks utility by @davidwendt in https://github.com/rapidsai/cudf/pull/20465
* Handle dealloc in stream-ordered cudf-polars ops by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20467
* Raise on unsupported unstack cases by @Matt711 in https://github.com/rapidsai/cudf/pull/20463
* Allow early exit for left semi-/anti- joins with empty build/probe tables by @shrshi in https://github.com/rapidsai/cudf/pull/20452
* Fix OOB memory access in JSON reader ingest_raw utility by @davidwendt in https://github.com/rapidsai/cudf/pull/20451
* Round up small-type groupby outputs to 4-byte boundary by @PointKernel in https://github.com/rapidsai/cudf/pull/20455
* Fix GPU acceleration bug in decimal type-cast by @galipremsagar in https://github.com/rapidsai/cudf/pull/20471
* Add missing CUDA stream in cudf_polars Distinct by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20477
* Support `__arrow_array__` on proxy extension array by @Matt711 in https://github.com/rapidsai/cudf/pull/20478
* Enable scan operation for `datetime64` and `timedelta64` types by @galipremsagar in https://github.com/rapidsai/cudf/pull/20464
* Remove unneeded type check in cudf::strings::slice_strings by @davidwendt in https://github.com/rapidsai/cudf/pull/20437
* Fix join match context tests by @PointKernel in https://github.com/rapidsai/cudf/pull/20472
* Fix the statistics_mr in benchmark fixture by @PointKernel in https://github.com/rapidsai/cudf/pull/20496
* Guard `__sizeof__` in pandas compatability mode by @Matt711 in https://github.com/rapidsai/cudf/pull/20495
* Fix OOB memory access in Orc and Parquet stacks from fixed-width unaligned loads by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20458
* Fix cudf.pandas Timestamp/Timedelta not subclassing stdlib datetime objects by @mroeschke in https://github.com/rapidsai/cudf/pull/20433
* Revert benchmark input generation logic for list type by @davidwendt in https://github.com/rapidsai/cudf/pull/20498
* Avoid using pylibcudf directly in rapidsmpf runtime by @rjzamora in https://github.com/rapidsai/cudf/pull/20501
* Suppress NVRTC arch warnings by @brandon-b-miller in https://github.com/rapidsai/cudf/pull/20517
* Fix ``ChannelManager`` and ``Lineariser`` by @rjzamora in https://github.com/rapidsai/cudf/pull/20516
* Synchronize streams in ``LocalShuffle`` by @rjzamora in https://github.com/rapidsai/cudf/pull/20515
* Make `argsort` have return type `np.intp` to match pandas by @Matt711 in https://github.com/rapidsai/cudf/pull/20487
* Fix `polars.concat_str` with one column in cudf_polars by @mroeschke in https://github.com/rapidsai/cudf/pull/20535
* Override `__sizeof__` for `cudf.Index` by @Matt711 in https://github.com/rapidsai/cudf/pull/20530
* Fix `pl.scan_csv(...).slice(...).collect(engine="gpu")` with None endpoint by @mroeschke in https://github.com/rapidsai/cudf/pull/20519
* Fix DataChunkSourceTest by syncing default stream by @davidwendt in https://github.com/rapidsai/cudf/pull/20492
* Fix data size errors in some libcudf benchmarks by @davidwendt in https://github.com/rapidsai/cudf/pull/20512
* Pin cython and pytest dependencies by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20571
* Pin Cython pre-3.2.0 and PyTest pre-9 by @jakirkham in https://github.com/rapidsai/cudf/pull/20573
* Handle `Empty` child IRs in `_decompose` by @Matt711 in https://github.com/rapidsai/cudf/pull/20409
* Skip flaky pandas datetime test by @Matt711 in https://github.com/rapidsai/cudf/pull/20585
* Fix max-pool-size-exceeded error in DATA_CHUNK_SOURCE_TEST by @davidwendt in https://github.com/rapidsai/cudf/pull/20534
* Fix racecheck in nvtext wordpiece tokenizer kernel by @davidwendt in https://github.com/rapidsai/cudf/pull/20588
* Fix the check to determine if all column chunk pages are dict encoded by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20524
* Add stream synchronize to QUANTILES_TEST PercentileApprox gtests by @davidwendt in https://github.com/rapidsai/cudf/pull/20558
* updated update-version.sh to handle release branch version changes by @rockhowse in https://github.com/rapidsai/cudf/pull/20598
* Fix nvtext tokenizers handling invalid UTF8 data by @davidwendt in https://github.com/rapidsai/cudf/pull/20514
* Fix overflow errors in distinct and filtered joins when hash table size exceeds int32 limits by @shrshi in https://github.com/rapidsai/cudf/pull/20594
* [FEA] Optimize JIT Filter for Low-Selectivity by @lamarrr in https://github.com/rapidsai/cudf/pull/20222
* Compute boolean function(NOT) on integers as a bitwise invert by @Matt711 in https://github.com/rapidsai/cudf/pull/20599
* Cast output dtype of rolling aggregations to match pandas by @Matt711 in https://github.com/rapidsai/cudf/pull/20526
* Add noop path for `Frame.astype` by @Matt711 in https://github.com/rapidsai/cudf/pull/20581
* Fix `copy` semantics bugs thus reduce copies and memory usage by @galipremsagar in https://github.com/rapidsai/cudf/pull/20121
* Ensure the sum after expression decomposition for mean has float output dtype by @Matt711 in https://github.com/rapidsai/cudf/pull/20596
* Use `Decimal(0)` literal for all-null decimal groups in groupby-sum by @Matt711 in https://github.com/rapidsai/cudf/pull/20591
* Do not drop `freq` when constructing `DatetimeIndex` from pandas by @brandon-b-miller in https://github.com/rapidsai/cudf/pull/18778
* Fix --validation flag for cudf.pandas PDSH benchmarks by @mroeschke in https://github.com/rapidsai/cudf/pull/20540
* Enable GPU acceleration for more binops by @galipremsagar in https://github.com/rapidsai/cudf/pull/20507
* Fix `rmm` function calls due to removed deprecated APIs and macro by @ttnghia in https://github.com/rapidsai/cudf/pull/20661
* Fix orc reader bool bug due to not being able to resume rle decode by @pmattione-nvidia in https://github.com/rapidsai/cudf/pull/20666
* Fix categorical comparisons in `cudf` to match `pandas` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20674
* Fix `any` and `all` to match pandas by @galipremsagar in https://github.com/rapidsai/cudf/pull/20679
* Fix return types of string APIs in `cudf.pandas` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20683
* Resolve pandas test failures  by @galipremsagar in https://github.com/rapidsai/cudf/pull/20704
* Fix DatetimeIndex pickling by @vyasr in https://github.com/rapidsai/cudf/pull/20709
* `DatetimeIndex.serialize()` headers are msgpack serializable by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20714
### 📖 Documentation
* Add note that --rmm-async only affects distributed scheduler. by @bdice in https://github.com/rapidsai/cudf/pull/20129
* Add profiling guide by @bdice in https://github.com/rapidsai/cudf/pull/20292
* Find RMM before CCCL by @wence- in https://github.com/rapidsai/cudf/pull/20336
* Use current system architecture in conda environment creation command by @bdice in https://github.com/rapidsai/cudf/pull/20500
* Use uname -m instead of arch command by @bdice in https://github.com/rapidsai/cudf/pull/20502
* Use RAPIDS_BRANCH file for documentation links by @bdice in https://github.com/rapidsai/cudf/pull/20494
### 🚀 New Features
* Add memory resources to unary, transform, and filling modules by @vyasr in https://github.com/rapidsai/cudf/pull/20054
* Add memory resources to binaryop, copying, and stream_compaction by @vyasr in https://github.com/rapidsai/cudf/pull/20059
* Add memory resources to groupby, datetime, and lists modules by @vyasr in https://github.com/rapidsai/cudf/pull/20102
* Add memory resources to search, reshape, and partitioning module by @vyasr in https://github.com/rapidsai/cudf/pull/20101
* Add memory resources to rolling, sorting, and quantiles modules by @vyasr in https://github.com/rapidsai/cudf/pull/20099
* [FEA] Implement JIT Filter for read_parquet by @lamarrr in https://github.com/rapidsai/cudf/pull/19831
* Add memory resources to all nvtext APIs by @vyasr in https://github.com/rapidsai/cudf/pull/20119
* Add memory resource to all strings modules by @vyasr in https://github.com/rapidsai/cudf/pull/20123
* Add memory resources to reduce, column, column_factories, and contiguous_split by @vyasr in https://github.com/rapidsai/cudf/pull/20135
* Add memory resources to I/O modules by @vyasr in https://github.com/rapidsai/cudf/pull/20136
* Remove rounding from cudf java by @pmattione-nvidia in https://github.com/rapidsai/cudf/pull/20110
* Add memory resources to replace, json, and hashing by @vyasr in https://github.com/rapidsai/cudf/pull/20150
* Add support for maintain_order param in joins by @Matt711 in https://github.com/rapidsai/cudf/pull/17698
* Add an example to inspect parquet files and dump row group and page level metadata information by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20117
* Support forward/backward filling null values in a grouped window context by @Matt711 in https://github.com/rapidsai/cudf/pull/19907
* Allow multiple calls to `cudf::initialize` and `cudf::deinitialize` by @vuule in https://github.com/rapidsai/cudf/pull/20111
* Add remaining memory resources by @vyasr in https://github.com/rapidsai/cudf/pull/20197
* Add memory resources to scalars by @vyasr in https://github.com/rapidsai/cudf/pull/20196
* Add pylibcudf is_valid_reduce_aggregation API by @davidwendt in https://github.com/rapidsai/cudf/pull/20145
* Support decimal literals in cudf-polars by @Matt711 in https://github.com/rapidsai/cudf/pull/20147
* Support `cum_sum(...).over(...)` expressions in cudf-polars by @Matt711 in https://github.com/rapidsai/cudf/pull/19908
* Passthrough unary ops through Parquet predicate pushdown by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20127
* Implement `ARGMIN` and `ARGMAX` aggregations for reduction by @ttnghia in https://github.com/rapidsai/cudf/pull/20207
* Skip decompression of pruned parquet pages by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20192
* Add an example to demonstrate the use of next-gen parquet reader to read a parquet file with highly selective filters by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/19469
* Evaluate `IS_NULL` at row group and page level in Parquet filtering by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20144
* [Java] Add optional native deps loader by @zpuller in https://github.com/rapidsai/cudf/pull/20414
* Add cudf-polars + rapidsmpf CI check by @rjzamora in https://github.com/rapidsai/cudf/pull/20355
* Add Python bindings for the hybrid scan reader by @vyasr in https://github.com/rapidsai/cudf/pull/20381
* RapidsMPF streaming-engine translation by @rjzamora in https://github.com/rapidsai/cudf/pull/20161
* [JNI] Use a read/write lock pattern in Rmm.class by @abellina in https://github.com/rapidsai/cudf/pull/20521
* [Java] Supports output projection indices for `contiguousSplitGroupsAndGenUniqKeys` by @res-life in https://github.com/rapidsai/cudf/pull/20391
* Support `Series.at` and `Series.iat` for pandas compatability by @Matt711 in https://github.com/rapidsai/cudf/pull/20529
* Add COUNT_VALID aggregation support to groupby-scan by @davidwendt in https://github.com/rapidsai/cudf/pull/20531
* Use RapidsMPF `read_parquet` in "rapidsmpf" runtime by @rjzamora in https://github.com/rapidsai/cudf/pull/20497
* Support decimal128 SUM aggregation in hash-based groupby by @PointKernel in https://github.com/rapidsai/cudf/pull/20509
* Add stream testing in pylibcudf by @vyasr in https://github.com/rapidsai/cudf/pull/20625
### 🛠️ Improvements
* Deprecate .from_pandas constructor by @mroeschke in https://github.com/rapidsai/cudf/pull/19996
* Prune entries in Sphinx nitpick_ignore by @mroeschke in https://github.com/rapidsai/cudf/pull/20045
* Avoid direct CategoricalColumn calls in dask_cudf by @mroeschke in https://github.com/rapidsai/cudf/pull/20080
* Fix typing issues in pylibcudf by @vyasr in https://github.com/rapidsai/cudf/pull/20069
* Avoid shadowing module names by @vyasr in https://github.com/rapidsai/cudf/pull/20071
* Remove calling to `purge_nonempty_nulls` in `make_lists_column` by @ttnghia in https://github.com/rapidsai/cudf/pull/12873
* Reduce verbosity of running the pandas test suite by @vyasr in https://github.com/rapidsai/cudf/pull/20107
* Clean up detail device atomic logic using atomic_ref by @PointKernel in https://github.com/rapidsai/cudf/pull/19924
* Use 8 processes for pandas tests, show top 10 test times by @bdice in https://github.com/rapidsai/cudf/pull/20109
* Update nvbench by @bdice in https://github.com/rapidsai/cudf/pull/19619
* Cleanup of some libcudf aggregation code by @davidwendt in https://github.com/rapidsai/cudf/pull/20053
* Run cudf-polars conda unit tests with more than 1 process by @mroeschke in https://github.com/rapidsai/cudf/pull/19980
* Avoid running pandas unit tests for private functionality with cudf.pandas by @mroeschke in https://github.com/rapidsai/cudf/pull/20115
* Remove MultiIndex.from_pandas pytest benchmark by @mroeschke in https://github.com/rapidsai/cudf/pull/20112
* Switch host_vector and host_span dependency by @davidwendt in https://github.com/rapidsai/cudf/pull/20106
* Have ListColumn.from_sequence go through pylibcudf by @mroeschke in https://github.com/rapidsai/cudf/pull/20098
* Fix `RAPIDS_BRANCH` version and update script by @galipremsagar in https://github.com/rapidsai/cudf/pull/20091
* Add pyarrow stubs to mypy environment and fix associated errors by @vyasr in https://github.com/rapidsai/cudf/pull/20118
* Fix slowdown in cudf-polars distributed tests by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20137
* Improve performance of string column size computation during parquet reads. by @nvdbaranec in https://github.com/rapidsai/cudf/pull/19986
* Disable async MR priming in cudf.pandas by @bdice in https://github.com/rapidsai/cudf/pull/20133
* Rework reduction case statement as dispatch_type_and_aggregation by @davidwendt in https://github.com/rapidsai/cudf/pull/20078
* Fix type annotations in cudf-polars by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20131
* Add tests for AUTO and HYBRID (de)compression modes by @vuule in https://github.com/rapidsai/cudf/pull/20126
* Branch 25.12 merge branch 25.10 by @vyasr in https://github.com/rapidsai/cudf/pull/20152
* Manual forward merger for Branch 25.12 - branch 25.10 by @galipremsagar in https://github.com/rapidsai/cudf/pull/20157
* Temporarily disable conda-java-tests by @bdice in https://github.com/rapidsai/cudf/pull/20162
* Remove unused ColumnBase.view by @mroeschke in https://github.com/rapidsai/cudf/pull/20141
* Avoid NumericalColumn call from CategoricalColumn.children by @mroeschke in https://github.com/rapidsai/cudf/pull/20153
* Deprecate legacy public row operators by @PointKernel in https://github.com/rapidsai/cudf/pull/20097
* Avoid more explicit calls to IntervalColumn and StructColumn by @mroeschke in https://github.com/rapidsai/cudf/pull/20064
* Run cudf-polars wheels unit tests with more than 1 process by @mroeschke in https://github.com/rapidsai/cudf/pull/20124
* Trace node execution in cudf-polars by @TomAugspurger in https://github.com/rapidsai/cudf/pull/19895
* Make ColumnBase.as_*_column convert via pylibcudf by @mroeschke in https://github.com/rapidsai/cudf/pull/20149
* Reduce execution times for parquet dictionary tests by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20176
* Update to rapids-logger 0.2 by @bdice in https://github.com/rapidsai/cudf/pull/20172
* Adjust rmm pool handling in PDSH benchmarks by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20138
* Don't assume cudf_polars benchmarking scale factor is always an integer by @mroeschke in https://github.com/rapidsai/cudf/pull/20182
* Skip filtering Parquet row groups with dictionaries if there are non-dict encoded pages by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20175
* Remove unnecessary work from `read_parquet_metadata` by @vuule in https://github.com/rapidsai/cudf/pull/20180
* Improve performance of groupby tdigests gtests by @davidwendt in https://github.com/rapidsai/cudf/pull/20173
* Revert "Temporarily disable conda-java-tests" by @bdice in https://github.com/rapidsai/cudf/pull/20184
* Add PDSH benchmark runner for cudf.pandas by @mroeschke in https://github.com/rapidsai/cudf/pull/20164
* Make Column.set_mask go through pylibcudf by @mroeschke in https://github.com/rapidsai/cudf/pull/20103
* Pin pydantic<2.12 in ci/test_cudf_polars_polars_tests.sh by @mroeschke in https://github.com/rapidsai/cudf/pull/20200
* Add an overhead field to cudf-polars tracing by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20198
* Support binops between float scalar to decimal column by @mroeschke in https://github.com/rapidsai/cudf/pull/20199
* Reduce output buffer sizes for pruned pages of columns with a `list` parent by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20086
* Make ListColumn._transform_leaves convert via pylibcudf by @mroeschke in https://github.com/rapidsai/cudf/pull/20151
* Rename `comparison_binop_generator` to `arg_minmax_binop_generator` and corresponding file to `nested_types_extrema_utils.cuh` by @Copilot in https://github.com/rapidsai/cudf/pull/20212
* Pin polars version <1.34 and >=1.29 by @Matt711 in https://github.com/rapidsai/cudf/pull/19912
* Stop using libcudf default parameters in pylibcudf by @vyasr in https://github.com/rapidsai/cudf/pull/20204
* Fix various typing errors by @vyasr in https://github.com/rapidsai/cudf/pull/20205
* Cleanup parquet for simple columns by @pmattione-nvidia in https://github.com/rapidsai/cudf/pull/19869
* Configuration for which metrics are enabled during tracing by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20223
* [pre-commit.ci] pre-commit autoupdate by @pre-commit-ci[bot] in https://github.com/rapidsai/cudf/pull/20189
* Fix parquet row number check for page bounds by @pmattione-nvidia in https://github.com/rapidsai/cudf/pull/20217
* More mypy and docs fixes by @vyasr in https://github.com/rapidsai/cudf/pull/20224
* Prevent accidental copies of expensive-to-copy object types by @vuule in https://github.com/rapidsai/cudf/pull/20226
* Split row operator header by @PointKernel in https://github.com/rapidsai/cudf/pull/20166
* Standardize setting StructDtype field names post libcudf conversion by @mroeschke in https://github.com/rapidsai/cudf/pull/20235
* Add arm testing of cudf.pandas unit tests by @vyasr in https://github.com/rapidsai/cudf/pull/20251
* Enable `sccache-dist` connection pool by @trxcllnt in https://github.com/rapidsai/cudf/pull/20264
* Run polars tests with the streaming and in-memory executors by @Matt711 in https://github.com/rapidsai/cudf/pull/19354
* Move and rename ``ScanPartitionPlan`` by @rjzamora in https://github.com/rapidsai/cudf/pull/20248
* Unpin DuckDB and Ibis in cudf.pandas thirdparty tests by @mroeschke in https://github.com/rapidsai/cudf/pull/20269
* Add pylibcudf to pre-commit linting and fix outstanding errors by @vyasr in https://github.com/rapidsai/cudf/pull/20250
* Update ``ConfigOptions`` for rapidsmpf-streaming integration by @rjzamora in https://github.com/rapidsai/cudf/pull/20252
* Handle unordered grouped windows properly for null filling and cum sums by @Matt711 in https://github.com/rapidsai/cudf/pull/20275
* Add more type annotations to cudf/core/column subclasses by @mroeschke in https://github.com/rapidsai/cudf/pull/20277
* Remove extraneous host_memory_resource include by @bdice in https://github.com/rapidsai/cudf/pull/20284
* Add `MultiIndex.dtypes` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20279
* Skip mypy in pre-commit.ci by @bdice in https://github.com/rapidsai/cudf/pull/20286
* Make ColumnBase.deserialize construct via pylibcudf by @mroeschke in https://github.com/rapidsai/cudf/pull/20142
* Add numpy to the mypy pre-commit environment by @vyasr in https://github.com/rapidsai/cudf/pull/20282
* Add ability to set the source_info of parquet_reader_options by @wence- in https://github.com/rapidsai/cudf/pull/20253
* Add more Python type annotations to `cudf/core` by @mroeschke in https://github.com/rapidsai/cudf/pull/20287
* Use main in RAPIDS_BRANCH by @bdice in https://github.com/rapidsai/cudf/pull/20312
* Move "All rights reserved" statements to copyright line by @KyleFromNVIDIA in https://github.com/rapidsai/cudf/pull/20313
* Add `inferred_type` and missing `IntervalIndex` properties by @galipremsagar in https://github.com/rapidsai/cudf/pull/20294
* Avoid unseeded, random data generation in cuDF classic tests by @mroeschke in https://github.com/rapidsai/cudf/pull/20319
* Improve hash-based groupby aggregation: direct write to the dense output columns whenever possible by @ttnghia in https://github.com/rapidsai/cudf/pull/19764
* Avoid accessing range values in cudf::strings::contains_re logic by @davidwendt in https://github.com/rapidsai/cudf/pull/20122
* Migrate mixed join to use the multiset data structure  by @PointKernel in https://github.com/rapidsai/cudf/pull/19989
* Add benchmark for strings cast to/from integer APIs by @davidwendt in https://github.com/rapidsai/cudf/pull/20247
* Use main shared-workflows branch by @bdice in https://github.com/rapidsai/cudf/pull/20324
* Use the thread pool for Parquet metadata processing by @vuule in https://github.com/rapidsai/cudf/pull/20263
* Add `.dt.day_of_week` and `.dt.daysinmonth` by @galipremsagar in https://github.com/rapidsai/cudf/pull/20298
* Avoid Column materialization in RangeIndex.nans_to_nulls by @mroeschke in https://github.com/rapidsai/cudf/pull/20331
* Update the code to be compatible with the new cuco stream-ordered allocator by @PointKernel in https://github.com/rapidsai/cudf/pull/20258
* Deprecate Series.data by @mroeschke in https://github.com/rapidsai/cudf/pull/20281
* Align cudf Python's Column constructors by @mroeschke in https://github.com/rapidsai/cudf/pull/20233
* Make type annotations of ColumnBase.set_mask stricter by @mroeschke in https://github.com/rapidsai/cudf/pull/20261
* Make type annotations of ColumnBase.find_and_replace stricter by @mroeschke in https://github.com/rapidsai/cudf/pull/20259
* Make type annotations of ColumnBase.apply_boolean_mask stricter by @mroeschke in https://github.com/rapidsai/cudf/pull/20262
* Skip Python LZ4 tests when nvCOMP is disabled by @vuule in https://github.com/rapidsai/cudf/pull/20293
* Move cudf/io/nvcomp_adapter.hpp to cudf/io/detail by @davidwendt in https://github.com/rapidsai/cudf/pull/20327
* Add context to IR.do_evaluate by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20322
* Update mypy `# type: ignore` comments according to stricter mypy configs by @mroeschke in https://github.com/rapidsai/cudf/pull/20272
* Remove duplicated enforce null consistency code by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20342
* Use SPDX for all copyright headers by @KyleFromNVIDIA in https://github.com/rapidsai/cudf/pull/20321
* Add more type annotations to `cudf/core/series.py` by @mroeschke in https://github.com/rapidsai/cudf/pull/20304
* Remove/Replace uses of numba.cuda arrays in pytest benchmarks and tests by @mroeschke in https://github.com/rapidsai/cudf/pull/20359
* Add duckdb pdsh query queries by @Matt711 in https://github.com/rapidsai/cudf/pull/20257
* Use stream in cudf_polars.DataFrame.to_polars by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20323
* Add `join_streams` to pylibcudf API by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20316
* Use CUDA streams in all pylibcudf calls made by cudf-polars by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20291
* Add cudf/io/config_utils.hpp to doxygen by @davidwendt in https://github.com/rapidsai/cudf/pull/20329
* Test coverage for parallel metadata parsing by @vuule in https://github.com/rapidsai/cudf/pull/20334
* Support serializing more polars types by @Matt711 in https://github.com/rapidsai/cudf/pull/20347
* Add CUDAStreamPolicy to cudf-polars configuration by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20366
* Unskip cudf-polars groupby test by @Matt711 in https://github.com/rapidsai/cudf/pull/20406
* Deprecate pylibcudf interop arrow APIs by @Matt711 in https://github.com/rapidsai/cudf/pull/20405
* Get rid of the hashing helper header by @PointKernel in https://github.com/rapidsai/cudf/pull/20360
* Minor cleanup and fixes for libcudf generate_input.cu by @davidwendt in https://github.com/rapidsai/cudf/pull/20363
* Ignore assert_produces_warning and shares_memory pandas unit tests for cudf.pandas by @mroeschke in https://github.com/rapidsai/cudf/pull/20434
* Short circut RangeIndex.append for length 0 input, proxy private attribute by @mroeschke in https://github.com/rapidsai/cudf/pull/20442
* Mark DataFrame.insert as _external_only_api by @Copilot in https://github.com/rapidsai/cudf/pull/20403
* Deprecate `get_current_device_resource` in favor of `get_current_device_resource_ref` by @PointKernel in https://github.com/rapidsai/cudf/pull/20386
* Promote `JoinNoneValue` to public as `JoinNoMatch` for clear non-match Join semantics by @PointKernel in https://github.com/rapidsai/cudf/pull/20440
* Remove duplicate entries in NODEIDS_THAT_FAIL_WITH_CUDF_PANDAS by @mroeschke in https://github.com/rapidsai/cudf/pull/20447
* Use the thread pool in the compact protocol reader by @vuule in https://github.com/rapidsai/cudf/pull/20417
* Update README.md generalizing all cuDF components by @mroeschke in https://github.com/rapidsai/cudf/pull/20357
* Skip TestDatetimelikeCoercion pandas tests that assert ._value identity by @mroeschke in https://github.com/rapidsai/cudf/pull/20459
* Add PSDH Q2-9 for cudf.pandas by @mroeschke in https://github.com/rapidsai/cudf/pull/20418
* Add s3fs to `test_cudf_python` common dependencies by @trxcllnt in https://github.com/rapidsai/cudf/pull/20473
* Use public pandas APIs in StringColumn.to_pandas by @mroeschke in https://github.com/rapidsai/cudf/pull/20474
* Expose java GatherMap internals and add toString to AST by @revans2 in https://github.com/rapidsai/cudf/pull/20483
* Add create_ascii_string_column to the libcudf benchmark data generator by @davidwendt in https://github.com/rapidsai/cudf/pull/20354
* Skip more pandas unit tests that tests BlockManager, private sparse types by @mroeschke in https://github.com/rapidsai/cudf/pull/20489
* Add boto3/botocore/aiobotocore to common test dependencies by @trxcllnt in https://github.com/rapidsai/cudf/pull/20490
* Use a lower bound when estimating the partial file-size by @rjzamora in https://github.com/rapidsai/cudf/pull/20193
* Performance improvement for nvtext::edit_distance for long strings by @davidwendt in https://github.com/rapidsai/cudf/pull/20268
* Add MemoryResourceConfig to cudf-polars config by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20042
* Improve project automation by @vyasr in https://github.com/rapidsai/cudf/pull/20523
* Fuse simple streaming reductions in cudf-polars by @rjzamora in https://github.com/rapidsai/cudf/pull/18757
* Migrate to new CCCL memory resource interface by @bdice in https://github.com/rapidsai/cudf/pull/20513
* Add empty input gtest for cudf::transform by @davidwendt in https://github.com/rapidsai/cudf/pull/20505
* Rework internal json headers to allow converting gtests files from .cu to .cpp by @davidwendt in https://github.com/rapidsai/cudf/pull/20491
* Set continue on error in the cudf-polars-rapidsmpf nightly CI job by @Matt711 in https://github.com/rapidsai/cudf/pull/20550
* Permanently back cuDF column by a pylibcudf.Column by @mroeschke in https://github.com/rapidsai/cudf/pull/20306
* Skip flaky upstream polars rolling test by @Matt711 in https://github.com/rapidsai/cudf/pull/20552
* Accelerate data page mask computation on device by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20280
* Change default rapidsmpf stream policy to 'pool' by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20527
* Increase gtests coverage for cudf::strings::like patterns by @davidwendt in https://github.com/rapidsai/cudf/pull/20348
* Add cuda::std::span operator to cudf::column_view by @davidwendt in https://github.com/rapidsai/cudf/pull/20541
* Update ArrowStringView compare benchmark for gather by @davidwendt in https://github.com/rapidsai/cudf/pull/19935
* Add pytest stubs and remove ujson usage by @vyasr in https://github.com/rapidsai/cudf/pull/20560
* Skip arrow array constructor tests by @Matt711 in https://github.com/rapidsai/cudf/pull/20579
* Add Polars to mypy environment and fix errors by @vyasr in https://github.com/rapidsai/cudf/pull/20563
* Ensure table chunks are unspilled and available by @madsbk in https://github.com/rapidsai/cudf/pull/20583
* Skip tests that assert behavior when copy-on-write is False by @Matt711 in https://github.com/rapidsai/cudf/pull/20506
* Pass streams through `Column.from_array`/`from_iterable_of_py` by @Matt711 in https://github.com/rapidsai/cudf/pull/20569
* Stop using Dtype annotation by @vyasr in https://github.com/rapidsai/cudf/pull/20590
* Workaround to enable running PDS-H via WebHDFS by @kingcrimsontianyu in https://github.com/rapidsai/cudf/pull/20132
* Update RMM includes from `<rmm/mr/device/*>` to `<rmm/mr/*>` by @bdice in https://github.com/rapidsai/cudf/pull/20607
* Stricter typing import for cudf-polars by @TomAugspurger in https://github.com/rapidsai/cudf/pull/20614
* Avoid the unnecessary H2H copy in the `std::vector` sink by @vuule in https://github.com/rapidsai/cudf/pull/20602
* Preprocessing offsets for Parquet non-dictionary string columns by @pmattione-nvidia in https://github.com/rapidsai/cudf/pull/20430
* Move more pandas unit tests that test private APIs by @mroeschke in https://github.com/rapidsai/cudf/pull/20511
* Use `.plc_column` instead of `.to_pylibcudf` in rolling, string utilties by @mroeschke in https://github.com/rapidsai/cudf/pull/20562
* Skip TestSetitemNADatetimeLikeDtype pandas unit tests due to private assertion by @mroeschke in https://github.com/rapidsai/cudf/pull/20578
* Pin Polars version <1.35 by @Matt711 in https://github.com/rapidsai/cudf/pull/20266
* Skip pandas unit tests in `test_old_base.py` that test private APIs by @mroeschke in https://github.com/rapidsai/cudf/pull/20572
* Use `.plc_column` attribute instead of `to_pylibcudf` more internally by @mroeschke in https://github.com/rapidsai/cudf/pull/20559
* Skip arrow-backed arithmetic tests and categorize the remaining failing tests by @Matt711 in https://github.com/rapidsai/cudf/pull/20577
* Fix a pytest execution that is spawned in a subprocess by @galipremsagar in https://github.com/rapidsai/cudf/pull/20660
* Accelerated parquet page header decoding when page index is available by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20369
* feat: add error handling for non-existent columns in parquet reader by @gforsyth in https://github.com/rapidsai/cudf/pull/20659
* Optimize row mask computation for single filter column by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20335
* Skip MultiIndex pandas unit tests testing private functionalty, `test_chaining_and_caching.py` by @mroeschke in https://github.com/rapidsai/cudf/pull/20575
* Address minor comments from recent hybrid scan PRs by @mhaseeb123 in https://github.com/rapidsai/cudf/pull/20672
* Add a timeout for the rapidsmpf test run by @vyasr in https://github.com/rapidsai/cudf/pull/20681
* Use `sccache-dist` build cluster for conda and wheel builds by @trxcllnt in https://github.com/rapidsai/cudf/pull/20488

## New Contributors
* @Copilot made their first contribution in https://github.com/rapidsai/cudf/pull/20212
* @rockhowse made their first contribution in https://github.com/rapidsai/cudf/pull/20598

**Full Changelog**: https://github.com/rapidsai/cudf/compare/v25.12.00a...release/25.12

# >>>>>>> END NEW CODE (2bdc9b336e)
# cudf 25.10.00 (8 Oct 2025)

## 🚨 Breaking Changes

- Remove UCX-Py ([#19979](https://github.com/rapidsai/cudf/pull/19979)) [@pentschev](https://github.com/pentschev)
- Revert &quot;Migrate mixed join to use multiset #19660&quot; ([#19933](https://github.com/rapidsai/cudf/pull/19933)) [@PointKernel](https://github.com/PointKernel)
- Fill missing values in `Series/Index.values` for numeric types with np.nan by default ([#19923](https://github.com/rapidsai/cudf/pull/19923)) [@mroeschke](https://github.com/mroeschke)
- Remove deprecated `DataFrame.apply_rows`, deprecate `DataFrame.apply_chunks` and `Groupby.apply_grouped` ([#19896](https://github.com/rapidsai/cudf/pull/19896)) [@mroeschke](https://github.com/mroeschke)
- Move prefetching out of experimental and simplify the API ([#19875](https://github.com/rapidsai/cudf/pull/19875)) [@vyasr](https://github.com/vyasr)
- Add join `*_match_context` APIs to hash join ([#19835](https://github.com/rapidsai/cudf/pull/19835)) [@PointKernel](https://github.com/PointKernel)
- Vendor libnvcomp in libcudf ([#19743](https://github.com/rapidsai/cudf/pull/19743)) [@bdice](https://github.com/bdice)
- Migrate mixed join to use multiset ([#19660](https://github.com/rapidsai/cudf/pull/19660)) [@PointKernel](https://github.com/PointKernel)
- Separate row mask and page mask computation and usage ([#19537](https://github.com/rapidsai/cudf/pull/19537)) [@mhaseeb123](https://github.com/mhaseeb123)
- [FEA] Implement null-aware transforms and filters ([#19502](https://github.com/rapidsai/cudf/pull/19502)) [@lamarrr](https://github.com/lamarrr)
- Support output-type for MEDIAN/QUANTILE aggregation in cudf::reduce ([#19267](https://github.com/rapidsai/cudf/pull/19267)) [@davidwendt](https://github.com/davidwendt)

## 🐛 Bug Fixes

- Fix edge cases in statistics collection ([#20094](https://github.com/rapidsai/cudf/pull/20094)) [@rjzamora](https://github.com/rjzamora)
- Fix multi-partition `Filter` bug ([#20075](https://github.com/rapidsai/cudf/pull/20075)) [@rjzamora](https://github.com/rjzamora)
- Fix `reindex` to fill only the reindexed values with `fill_value` ([#20063](https://github.com/rapidsai/cudf/pull/20063)) [@galipremsagar](https://github.com/galipremsagar)
- Fix arrow arrays + numpy ufunc interaction ([#20047](https://github.com/rapidsai/cudf/pull/20047)) [@galipremsagar](https://github.com/galipremsagar)
- Fix race conditions in ORC reader decimal decoding ([#20044](https://github.com/rapidsai/cudf/pull/20044)) [@vuule](https://github.com/vuule)
- Keep mr alive along with arrow tables and columns ([#20028](https://github.com/rapidsai/cudf/pull/20028)) [@vyasr](https://github.com/vyasr)
- Fix `value_counts` missing `nan` bug ([#20026](https://github.com/rapidsai/cudf/pull/20026)) [@galipremsagar](https://github.com/galipremsagar)
- Compatibility for rapidsmpf&#39;s unspill_partitions ([#20020](https://github.com/rapidsai/cudf/pull/20020)) [@TomAugspurger](https://github.com/TomAugspurger)
- Fix type metadata preservation in `shift` ([#20017](https://github.com/rapidsai/cudf/pull/20017)) [@galipremsagar](https://github.com/galipremsagar)
- Fix incorrect type propagation in dataframe assignment ([#20010](https://github.com/rapidsai/cudf/pull/20010)) [@galipremsagar](https://github.com/galipremsagar)
- Fix OOB memory read in decode_page_data_generic kernel ([#19995](https://github.com/rapidsai/cudf/pull/19995)) [@davidwendt](https://github.com/davidwendt)
- Fix data_type creation in ast::operation::instantiate ([#19994](https://github.com/rapidsai/cudf/pull/19994)) [@davidwendt](https://github.com/davidwendt)
- Skip Narwhals pandas get_dtype_backend[pyarrow] tests after ArrowDtype proxy changes ([#19992](https://github.com/rapidsai/cudf/pull/19992)) [@Matt711](https://github.com/Matt711)
- Make cudf.pandas callables usable with inspect.getfullargspec ([#19988](https://github.com/rapidsai/cudf/pull/19988)) [@mroeschke](https://github.com/mroeschke)
- Align decimal dtypes to schema after parquet IO scan ([#19974](https://github.com/rapidsai/cudf/pull/19974)) [@Matt711](https://github.com/Matt711)
- Avoid undefined numpy protocols on cudf.pandas proxy objects ([#19968](https://github.com/rapidsai/cudf/pull/19968)) [@mroeschke](https://github.com/mroeschke)
- Skip failing polars iceberg test ([#19955](https://github.com/rapidsai/cudf/pull/19955)) [@Matt711](https://github.com/Matt711)
- Revert &quot;Migrate mixed join to use multiset #19660&quot; ([#19933](https://github.com/rapidsai/cudf/pull/19933)) [@PointKernel](https://github.com/PointKernel)
- Define FrozenList proxy independently in cudf.pandas ([#19931](https://github.com/rapidsai/cudf/pull/19931)) [@mroeschke](https://github.com/mroeschke)
- Ignore scalars when broadcasting for horizontal string concatenation in cudf-polars ([#19893](https://github.com/rapidsai/cudf/pull/19893)) [@Matt711](https://github.com/Matt711)
- Fix is_valid_rolling_aggregation for STD aggregation ([#19888](https://github.com/rapidsai/cudf/pull/19888)) [@davidwendt](https://github.com/davidwendt)
- Fix a decompression parameter in the chunked ORC reader ([#19882](https://github.com/rapidsai/cudf/pull/19882)) [@vuule](https://github.com/vuule)
- Skip flaky stats tests pending follow up ([#19881](https://github.com/rapidsai/cudf/pull/19881)) [@brandon-b-miller](https://github.com/brandon-b-miller)
- Require list type for is_valid_aggregation and MERGE_LISTS/SETS ([#19876](https://github.com/rapidsai/cudf/pull/19876)) [@davidwendt](https://github.com/davidwendt)
- Temporary solution to ensure data-source/sink stream ordering ([#19874](https://github.com/rapidsai/cudf/pull/19874)) [@kingcrimsontianyu](https://github.com/kingcrimsontianyu)
- Check for integer overflow in cudf::strings::find_multiple ([#19867](https://github.com/rapidsai/cudf/pull/19867)) [@davidwendt](https://github.com/davidwendt)
- Fix missing stream from cudf::top_k_order ([#19866](https://github.com/rapidsai/cudf/pull/19866)) [@davidwendt](https://github.com/davidwendt)
- Disallow loc.__setitem__ with list-like indexer when list elements not in index ([#19851](https://github.com/rapidsai/cudf/pull/19851)) [@mroeschke](https://github.com/mroeschke)
- Fix .str.replace ignoring n for single character replacements ([#19848](https://github.com/rapidsai/cudf/pull/19848)) [@mroeschke](https://github.com/mroeschke)
- Fix strings::find_instance warp parallel logic ([#19845](https://github.com/rapidsai/cudf/pull/19845)) [@davidwendt](https://github.com/davidwendt)
- Add changed-files to the needs of every job that requires it ([#19830](https://github.com/rapidsai/cudf/pull/19830)) [@Matt711](https://github.com/Matt711)
- xfail polars `decimal(precision=None)` test ([#19821](https://github.com/rapidsai/cudf/pull/19821)) [@Matt711](https://github.com/Matt711)
- Fix empty column returned by cudf::from_arrow_stream_column ([#19812](https://github.com/rapidsai/cudf/pull/19812)) [@davidwendt](https://github.com/davidwendt)
- Filter pandas warning in dask_cudf test ([#19808](https://github.com/rapidsai/cudf/pull/19808)) [@TomAugspurger](https://github.com/TomAugspurger)
- Update identify_stream_usage CUDA runtime hooks to CUDA 13 ([#19807](https://github.com/rapidsai/cudf/pull/19807)) [@robertmaynard](https://github.com/robertmaynard)
- When bundling `libnvcomp.so.X` only append the major version value ([#19786](https://github.com/rapidsai/cudf/pull/19786)) [@robertmaynard](https://github.com/robertmaynard)
- Improvements to `pylibcudf.from_iterable_of_py` ([#19781](https://github.com/rapidsai/cudf/pull/19781)) [@Matt711](https://github.com/Matt711)
- Avoid using multiple `Cache` nodes with the same hash ([#19769](https://github.com/rapidsai/cudf/pull/19769)) [@rjzamora](https://github.com/rjzamora)
- Fix window var() test failures from float rounding ([#19761](https://github.com/rapidsai/cudf/pull/19761)) [@Matt711](https://github.com/Matt711)
- Use `is_compressed` field from Parquet V2 data page headers to determine if they are compressed ([#19755](https://github.com/rapidsai/cudf/pull/19755)) [@mhaseeb123](https://github.com/mhaseeb123)
- Fix bug in `eval` function with `nvtx-0.2.11` ([#19754](https://github.com/rapidsai/cudf/pull/19754)) [@galipremsagar](https://github.com/galipremsagar)
- Fix ndsh benchmarks nvtx range usage ([#19753](https://github.com/rapidsai/cudf/pull/19753)) [@davidwendt](https://github.com/davidwendt)
- Support `nan` in non-floating point column in cudf-polars ([#19742](https://github.com/rapidsai/cudf/pull/19742)) [@Matt711](https://github.com/Matt711)
- Fix filter call in benchmark ([#19732](https://github.com/rapidsai/cudf/pull/19732)) [@vyasr](https://github.com/vyasr)
- Suppress NVRTC warning from stdint.h ([#19712](https://github.com/rapidsai/cudf/pull/19712)) [@davidwendt](https://github.com/davidwendt)
- Correctly decode boolean lists in chunked parquet reader ([#19707](https://github.com/rapidsai/cudf/pull/19707)) [@mhaseeb123](https://github.com/mhaseeb123)
- Add new xfails for xarray release ([#19705](https://github.com/rapidsai/cudf/pull/19705)) [@vyasr](https://github.com/vyasr)
- Fix &quot;--executor&quot; pytest parameter for cudf-polars ([#19703](https://github.com/rapidsai/cudf/pull/19703)) [@rjzamora](https://github.com/rjzamora)
- Match polars semantics for rolling-sum with all-null windows (non-empty) ([#19680](https://github.com/rapidsai/cudf/pull/19680)) [@Matt711](https://github.com/Matt711)
- [BUG] Set `query_set` arg when validating/running cudf-polars PDS-DS benchmarks ([#19674](https://github.com/rapidsai/cudf/pull/19674)) [@Matt711](https://github.com/Matt711)
- Fix `group_by().agg()` on non-aggregatable dtypes ([#19669](https://github.com/rapidsai/cudf/pull/19669)) [@Matt711](https://github.com/Matt711)
- Fix broken links in 10min notebook ([#19665](https://github.com/rapidsai/cudf/pull/19665)) [@Matt711](https://github.com/Matt711)
- Skip managed memory test if managed memory not supported in cudf-polars ([#19653](https://github.com/rapidsai/cudf/pull/19653)) [@Matt711](https://github.com/Matt711)
- Fix integer overflow in warp-per-row grid calculation ([#19638](https://github.com/rapidsai/cudf/pull/19638)) [@davidwendt](https://github.com/davidwendt)
- Propagate exceptions thrown in async IO operations ([#19628](https://github.com/rapidsai/cudf/pull/19628)) [@vuule](https://github.com/vuule)
- Make `DataFrame.dtypes` not fallback to CPU always ([#19627](https://github.com/rapidsai/cudf/pull/19627)) [@galipremsagar](https://github.com/galipremsagar)
- Set scalar to valid in range_window_bounds unbounded/current_row ([#19622](https://github.com/rapidsai/cudf/pull/19622)) [@davidwendt](https://github.com/davidwendt)
- Enable data page mask computation for nullable `list` and `struct` columns ([#19617](https://github.com/rapidsai/cudf/pull/19617)) [@mhaseeb123](https://github.com/mhaseeb123)
- Fix cudf::sequence() to throw exception for invalid scalar inputs ([#19612](https://github.com/rapidsai/cudf/pull/19612)) [@davidwendt](https://github.com/davidwendt)
- Fix uninitialized variable and misaligned write in parquet generic decoder ([#19601](https://github.com/rapidsai/cudf/pull/19601)) [@mhaseeb123](https://github.com/mhaseeb123)
- Compatibility with rapidsmpf 25.10.0 ([#19591](https://github.com/rapidsai/cudf/pull/19591)) [@TomAugspurger](https://github.com/TomAugspurger)
- Avoid querying device memory on systems without it in dask-cudf ([#19577](https://github.com/rapidsai/cudf/pull/19577)) [@Matt711](https://github.com/Matt711)
- Avoid querying device memory on systems without it in cudf-polars benchmarks ([#19575](https://github.com/rapidsai/cudf/pull/19575)) [@Matt711](https://github.com/Matt711)
- Increase alignment requirement for parquet bloom filter to 256 ([#19573](https://github.com/rapidsai/cudf/pull/19573)) [@mhaseeb123](https://github.com/mhaseeb123)
- Fix strftime with non-exact %a, %A, %b, %B ([#19570](https://github.com/rapidsai/cudf/pull/19570)) [@mroeschke](https://github.com/mroeschke)
- Fix OOB memcheck error in group_rank_to_percentage utility ([#19567](https://github.com/rapidsai/cudf/pull/19567)) [@davidwendt](https://github.com/davidwendt)
- Fix logic for number of unique values generated by data profile in benchmarks ([#19540](https://github.com/rapidsai/cudf/pull/19540)) [@shrshi](https://github.com/shrshi)
- Fix contiguous-split nvbench cmake build ([#19534](https://github.com/rapidsai/cudf/pull/19534)) [@davidwendt](https://github.com/davidwendt)
- Fix value counts expression when the column has nulls ([#19524](https://github.com/rapidsai/cudf/pull/19524)) [@Matt711](https://github.com/Matt711)
- Prefer `Column.astype` over `plc.unary.cast` in the fill null unary function expression ([#19479](https://github.com/rapidsai/cudf/pull/19479)) [@Matt711](https://github.com/Matt711)
- Fix missing return in StringFunction.Strptime strict=True path ([#19464](https://github.com/rapidsai/cudf/pull/19464)) [@Matt711](https://github.com/Matt711)
- Make dividing a boolean column return f64 dtype in cudf-polars ([#19443](https://github.com/rapidsai/cudf/pull/19443)) [@Matt711](https://github.com/Matt711)
- branch-25.10-merge-branch-25.08 ([#19429](https://github.com/rapidsai/cudf/pull/19429)) [@davidwendt](https://github.com/davidwendt)
- Replace sprintf with std::format in libcudf parquet tests ([#19364](https://github.com/rapidsai/cudf/pull/19364)) [@davidwendt](https://github.com/davidwendt)

## 📖 Documentation

- Update missing docs ([#19925](https://github.com/rapidsai/cudf/pull/19925)) [@vyasr](https://github.com/vyasr)
- Add examples of null handling to doxygen for cudf::rank ([#19774](https://github.com/rapidsai/cudf/pull/19774)) [@davidwendt](https://github.com/davidwendt)
- Fix cudf-polars dependency list docs ([#19750](https://github.com/rapidsai/cudf/pull/19750)) [@pentschev](https://github.com/pentschev)
- Update cuDF classic testing documention regarding testing organization ([#19745](https://github.com/rapidsai/cudf/pull/19745)) [@mroeschke](https://github.com/mroeschke)
- Improve documentation around why we need no_gc_clear on pylibcudf Scalars ([#19661](https://github.com/rapidsai/cudf/pull/19661)) [@vyasr](https://github.com/vyasr)

## 🚀 New Features

- Add memory resource parameters to interop, merge, and transpose ([#20007](https://github.com/rapidsai/cudf/pull/20007)) [@vyasr](https://github.com/vyasr)
- Add mixed join benchmark with complex AST operators ([#20004](https://github.com/rapidsai/cudf/pull/20004)) [@PointKernel](https://github.com/PointKernel)
- Add memory resource arguments to join, round, and labeling ([#20001](https://github.com/rapidsai/cudf/pull/20001)) [@vyasr](https://github.com/vyasr)
- `cudf-polars` `strptime` format inference ([#19997](https://github.com/rapidsai/cudf/pull/19997)) [@brandon-b-miller](https://github.com/brandon-b-miller)
- Filter parquet row groups using byte offset bounds ([#19991](https://github.com/rapidsai/cudf/pull/19991)) [@mhaseeb123](https://github.com/mhaseeb123)
- Add memory resource arguments to concatenate ([#19943](https://github.com/rapidsai/cudf/pull/19943)) [@vyasr](https://github.com/vyasr)
- Use column statistics to generate the physical plan in cuDF-Polars ([#19940](https://github.com/rapidsai/cudf/pull/19940)) [@rjzamora](https://github.com/rjzamora)
- Add all missing stream parameters ([#19922](https://github.com/rapidsai/cudf/pull/19922)) [@vyasr](https://github.com/vyasr)
- Remote IO support in cudf-polars ([#19921](https://github.com/rapidsai/cudf/pull/19921)) [@Matt711](https://github.com/Matt711)
- Add streams to io/timezone and io/text modules ([#19913](https://github.com/rapidsai/cudf/pull/19913)) [@vyasr](https://github.com/vyasr)
- Add stream support to all nvtext modules ([#19911](https://github.com/rapidsai/cudf/pull/19911)) [@vyasr](https://github.com/vyasr)
- Add streams to all top-level strings modules ([#19910](https://github.com/rapidsai/cudf/pull/19910)) [@vyasr](https://github.com/vyasr)
- Update strings split APIs with stream parameters ([#19909](https://github.com/rapidsai/cudf/pull/19909)) [@vyasr](https://github.com/vyasr)
- Support ordered grouped windows in cudf-polars ([#19891](https://github.com/rapidsai/cudf/pull/19891)) [@Matt711](https://github.com/Matt711)
- Add local row-count and unique-count estimates to `explain(... logical=True)` ([#19864](https://github.com/rapidsai/cudf/pull/19864)) [@rjzamora](https://github.com/rjzamora)
- Add join `*_match_context` APIs to hash join ([#19835](https://github.com/rapidsai/cudf/pull/19835)) [@PointKernel](https://github.com/PointKernel)
- Support `rank(...).over(...)` expressions in cudf-polars ([#19803](https://github.com/rapidsai/cudf/pull/19803)) [@Matt711](https://github.com/Matt711)
- Add strings to/from encoded integer APIs ([#19789](https://github.com/rapidsai/cudf/pull/19789)) [@davidwendt](https://github.com/davidwendt)
- Add to_arrow method to pylibcudf core types ([#19787](https://github.com/rapidsai/cudf/pull/19787)) [@Matt711](https://github.com/Matt711)
- Add streams to strings convert APIs ([#19780](https://github.com/rapidsai/cudf/pull/19780)) [@vyasr](https://github.com/vyasr)
- Add an option to support reading ORC timestamp column as UTC time. ([#19773](https://github.com/rapidsai/cudf/pull/19773)) [@res-life](https://github.com/res-life)
- Support null_count in groupby/rolling context ([#19739](https://github.com/rapidsai/cudf/pull/19739)) [@Matt711](https://github.com/Matt711)
- Collect join-key information in cudf-polars ([#19736](https://github.com/rapidsai/cudf/pull/19736)) [@rjzamora](https://github.com/rjzamora)
- Add count aggregation support to cudf::reduce ([#19734](https://github.com/rapidsai/cudf/pull/19734)) [@davidwendt](https://github.com/davidwendt)
- [FEA] Implement AST Expression - JIT codegen ([#19733](https://github.com/rapidsai/cudf/pull/19733)) [@lamarrr](https://github.com/lamarrr)
- Add streams to all scalar factories ([#19729](https://github.com/rapidsai/cudf/pull/19729)) [@vyasr](https://github.com/vyasr)
- Add streams to reshape ([#19728](https://github.com/rapidsai/cudf/pull/19728)) [@vyasr](https://github.com/vyasr)
- Add streams to null mask APIs ([#19727](https://github.com/rapidsai/cudf/pull/19727)) [@vyasr](https://github.com/vyasr)
- Add streams to column APIs ([#19726](https://github.com/rapidsai/cudf/pull/19726)) [@vyasr](https://github.com/vyasr)
- Construct next-gen parquet reader with pre-populated footer ([#19724](https://github.com/rapidsai/cudf/pull/19724)) [@mhaseeb123](https://github.com/mhaseeb123)
- Require `numba-cuda&gt;=0.19.0,&lt;0.20.0a0` ([#19711](https://github.com/rapidsai/cudf/pull/19711)) [@brandon-b-miller](https://github.com/brandon-b-miller)
- Support `over` expression (window mapping) in cudf-polars ([#19684](https://github.com/rapidsai/cudf/pull/19684)) [@Matt711](https://github.com/Matt711)
- Add streams support to all list APIs ([#19683](https://github.com/rapidsai/cudf/pull/19683)) [@vyasr](https://github.com/vyasr)
- [FEA] Add Filter Benchmark ([#19678](https://github.com/rapidsai/cudf/pull/19678)) [@lamarrr](https://github.com/lamarrr)
- Add streams to pylibcudf join APIs ([#19672](https://github.com/rapidsai/cudf/pull/19672)) [@vyasr](https://github.com/vyasr)
- Add streams to sorting APIs ([#19671](https://github.com/rapidsai/cudf/pull/19671)) [@vyasr](https://github.com/vyasr)
- [FEA] Remove excessive copies of JITIFY&#39;s ProgramData during JIT kernel launch ([#19667](https://github.com/rapidsai/cudf/pull/19667)) [@lamarrr](https://github.com/lamarrr)
- Add streams to hashing APIs ([#19663](https://github.com/rapidsai/cudf/pull/19663)) [@vyasr](https://github.com/vyasr)
- Use a more robust metric for sorting (de)compression tasks ([#19656](https://github.com/rapidsai/cudf/pull/19656)) [@vuule](https://github.com/vuule)
- Add streams support to datetime APIs ([#19654](https://github.com/rapidsai/cudf/pull/19654)) [@vyasr](https://github.com/vyasr)
- Add streams to stream_compaction ([#19651](https://github.com/rapidsai/cudf/pull/19651)) [@vyasr](https://github.com/vyasr)
- Enable casting `pl.Datetime` to integer types in `cudf-polars` ([#19647](https://github.com/rapidsai/cudf/pull/19647)) [@brandon-b-miller](https://github.com/brandon-b-miller)
- Add Java JNI interface to get Gpu UUID ([#19646](https://github.com/rapidsai/cudf/pull/19646)) [@res-life](https://github.com/res-life)
- Add reduction with overflow detection ([#19641](https://github.com/rapidsai/cudf/pull/19641)) [@PointKernel](https://github.com/PointKernel)
- Upgrade to nvCOMP 5.0.0.6 ([#19636](https://github.com/rapidsai/cudf/pull/19636)) [@vuule](https://github.com/vuule)
- Use the nvCOMP 5.0 API to better estimate decompression memory requirements ([#19616](https://github.com/rapidsai/cudf/pull/19616)) [@vuule](https://github.com/vuule)
- Add streams to transform and unary ([#19613](https://github.com/rapidsai/cudf/pull/19613)) [@vyasr](https://github.com/vyasr)
- Add streams to all modules with 4-5 functions ([#19609](https://github.com/rapidsai/cudf/pull/19609)) [@vyasr](https://github.com/vyasr)
- Enable casting integer dtypes to `pl.Datetime` via `cudf-polars` ([#19607](https://github.com/rapidsai/cudf/pull/19607)) [@brandon-b-miller](https://github.com/brandon-b-miller)
- Add fast path for Parquet reading with predicate pushdown via AST filters ([#19605](https://github.com/rapidsai/cudf/pull/19605)) [@Matt711](https://github.com/Matt711)
- Add streams to all modules with three or fewer functions ([#19600](https://github.com/rapidsai/cudf/pull/19600)) [@vyasr](https://github.com/vyasr)
- Add libcudf top_k_segmented APIs ([#19597](https://github.com/rapidsai/cudf/pull/19597)) [@davidwendt](https://github.com/davidwendt)
- Update Arrow bounds to &gt;=15,&lt;22 ([#19592](https://github.com/rapidsai/cudf/pull/19592)) [@bdice](https://github.com/bdice)
- Update cudf to handle CUDA 13 changes ([#19585](https://github.com/rapidsai/cudf/pull/19585)) [@robertmaynard](https://github.com/robertmaynard)
- Support hash-based workflow for `M2` groupby aggregation ([#19569](https://github.com/rapidsai/cudf/pull/19569)) [@ttnghia](https://github.com/ttnghia)
- Expose `filter` and `columns` parquet reader builder options to python ([#19566](https://github.com/rapidsai/cudf/pull/19566)) [@Matt711](https://github.com/Matt711)
- [FEA] Switch to NVIDIA&#39;s JITIFY2 ([#19561](https://github.com/rapidsai/cudf/pull/19561)) [@lamarrr](https://github.com/lamarrr)
- Add streams to all single-function modules ([#19559](https://github.com/rapidsai/cudf/pull/19559)) [@vyasr](https://github.com/vyasr)
- Add support for streams to all copying APIs. ([#19553](https://github.com/rapidsai/cudf/pull/19553)) [@vyasr](https://github.com/vyasr)
- Benchmarks comparing Arrow string formats ([#19552](https://github.com/rapidsai/cudf/pull/19552)) [@davidwendt](https://github.com/davidwendt)
- Compile `libcudf_kafka` and `cudf_kafka` with C++20 ([#19543](https://github.com/rapidsai/cudf/pull/19543)) [@vuule](https://github.com/vuule)
- RapidsMPF &quot;single&quot; shuffle integration ([#19530](https://github.com/rapidsai/cudf/pull/19530)) [@rjzamora](https://github.com/rjzamora)
- Make nvCOMP ZLIB (de)compression available by default ([#19528](https://github.com/rapidsai/cudf/pull/19528)) [@vuule](https://github.com/vuule)
- Implement chunking in the next-gen parquet reader ([#19526](https://github.com/rapidsai/cudf/pull/19526)) [@mhaseeb123](https://github.com/mhaseeb123)
- Add primitive row dispatch support for semi/anti join and cudf::contains ([#19518](https://github.com/rapidsai/cudf/pull/19518)) [@PointKernel](https://github.com/PointKernel)
- Derive and use page mask at subpass level for chunked reads ([#19515](https://github.com/rapidsai/cudf/pull/19515)) [@mhaseeb123](https://github.com/mhaseeb123)
- [FEA] Implement null-aware transforms and filters ([#19502](https://github.com/rapidsai/cudf/pull/19502)) [@lamarrr](https://github.com/lamarrr)
- Add PDS-DS queries 2 through 10 to cudf-polars benchmarks ([#19488](https://github.com/rapidsai/cudf/pull/19488)) [@Matt711](https://github.com/Matt711)
- Add API to &quot;initialize&quot; column statistics ([#19447](https://github.com/rapidsai/cudf/pull/19447)) [@rjzamora](https://github.com/rjzamora)
- Implement top k expression in cudf-polars using `cudf::top_k` ([#19431](https://github.com/rapidsai/cudf/pull/19431)) [@Matt711](https://github.com/Matt711)
- Add hash-based SUM_WITH_OVERFLOW aggregation for INT64 values ([#19403](https://github.com/rapidsai/cudf/pull/19403)) [@PointKernel](https://github.com/PointKernel)
- Support rank expression in cudf-polars ([#19340](https://github.com/rapidsai/cudf/pull/19340)) [@Matt711](https://github.com/Matt711)
- Support fill_null with fill strategy in cudf-polars ([#19318](https://github.com/rapidsai/cudf/pull/19318)) [@Matt711](https://github.com/Matt711)
- Support output-type for MEDIAN/QUANTILE aggregation in cudf::reduce ([#19267](https://github.com/rapidsai/cudf/pull/19267)) [@davidwendt](https://github.com/davidwendt)
- Support ternary expression inside groupby/rolling context ([#19242](https://github.com/rapidsai/cudf/pull/19242)) [@Matt711](https://github.com/Matt711)
- Experimental API to read a parquet table, build a custom index column, and apply roaring bitmap deletion vector ([#19237](https://github.com/rapidsai/cudf/pull/19237)) [@mhaseeb123](https://github.com/mhaseeb123)
- Support `cudf-polars` `str.zfill` ([#19081](https://github.com/rapidsai/cudf/pull/19081)) [@brandon-b-miller](https://github.com/brandon-b-miller)
- [FEA] Add chunked Parquet sink support using the libcudf writer ([#19015](https://github.com/rapidsai/cudf/pull/19015)) [@Matt711](https://github.com/Matt711)
- Add multi-column support for primitive row operator dispatch ([#18940](https://github.com/rapidsai/cudf/pull/18940)) [@tgujar](https://github.com/tgujar)

## 🛠️ Improvements

- Fix CI failures for `pandas-2.3.3` ([#20146](https://github.com/rapidsai/cudf/pull/20146)) [@galipremsagar](https://github.com/galipremsagar)
- Skip passing failures for latest `numexpr` version ([#20092](https://github.com/rapidsai/cudf/pull/20092)) [@galipremsagar](https://github.com/galipremsagar)
- Empty commit to trigger a build ([#20084](https://github.com/rapidsai/cudf/pull/20084)) [@msarahan](https://github.com/msarahan)
- Update the reason to skip for parquet bloom filter test ([#20043](https://github.com/rapidsai/cudf/pull/20043)) [@mhaseeb123](https://github.com/mhaseeb123)
- Remove test_scan_hf_url_raises ([#20035](https://github.com/rapidsai/cudf/pull/20035)) [@mroeschke](https://github.com/mroeschke)
- xfail(strict=False) test_scan_hf_url_raises due to rate limiting ([#20027](https://github.com/rapidsai/cudf/pull/20027)) [@mroeschke](https://github.com/mroeschke)
- Deprecate left semi- and anti- join functional APIs ([#20014](https://github.com/rapidsai/cudf/pull/20014)) [@shrshi](https://github.com/shrshi)
- Use to_arrow methods throughout pylibcudf and cudf ([#20013](https://github.com/rapidsai/cudf/pull/20013)) [@Matt711](https://github.com/Matt711)
- Fix chunked reads of list of bools. ([#20000](https://github.com/rapidsai/cudf/pull/20000)) [@pmattione-nvidia](https://github.com/pmattione-nvidia)
- Raise more exceptions for invalid or unsupported cuDF arguments ([#19990](https://github.com/rapidsai/cudf/pull/19990)) [@mroeschke](https://github.com/mroeschke)
- Configure repo for automatic release notes generation ([#19984](https://github.com/rapidsai/cudf/pull/19984)) [@AyodeAwe](https://github.com/AyodeAwe)
- Pin duckdb&lt;1.4 in test_python_narwhals ([#19982](https://github.com/rapidsai/cudf/pull/19982)) [@mroeschke](https://github.com/mroeschke)
- Default to False if `CUDA_ENABLE_NRT` isn&#39;t set in config ([#19981](https://github.com/rapidsai/cudf/pull/19981)) [@brandon-b-miller](https://github.com/brandon-b-miller)
- Remove UCX-Py ([#19979](https://github.com/rapidsai/cudf/pull/19979)) [@pentschev](https://github.com/pentschev)
- Add support for `attrs` ([#19978](https://github.com/rapidsai/cudf/pull/19978)) [@galipremsagar](https://github.com/galipremsagar)
- Run pytest-benchmarks in CI with --benchmark-disable ([#19969](https://github.com/rapidsai/cudf/pull/19969)) [@mroeschke](https://github.com/mroeschke)
- Change target type so we can test on workflows ([#19963](https://github.com/rapidsai/cudf/pull/19963)) [@vyasr](https://github.com/vyasr)
- Update to actions/labeler v5 ([#19962](https://github.com/rapidsai/cudf/pull/19962)) [@vyasr](https://github.com/vyasr)
- Revert &quot;ci(labeler): update labeler action to [@v5&quot; ([#19961](https://github.com/rapidsai/cudf/pull/19961)) @vyasr](https://github.com/v5&quot; ([#19961](https://github.com/rapidsai/cudf/pull/19961)) @vyasr)
- Add `ArrowDtype` proxy class ([#19960](https://github.com/rapidsai/cudf/pull/19960)) [@galipremsagar](https://github.com/galipremsagar)
- Add missing type stub ([#19958](https://github.com/rapidsai/cudf/pull/19958)) [@vyasr](https://github.com/vyasr)
- Add missing `Styler` attributes ([#19956](https://github.com/rapidsai/cudf/pull/19956)) [@galipremsagar](https://github.com/galipremsagar)
- Allow newer CMake in Java tests ([#19949](https://github.com/rapidsai/cudf/pull/19949)) [@bdice](https://github.com/bdice)
- Make stream a required parameter for from_libcudf methods ([#19945](https://github.com/rapidsai/cudf/pull/19945)) [@vyasr](https://github.com/vyasr)
- Return False instead of NA for comparison ops against NA in cudf.pandas ([#19942](https://github.com/rapidsai/cudf/pull/19942)) [@mroeschke](https://github.com/mroeschke)
- Don&#39;t fall back in Series.describe in cudf.pandas for numeric types ([#19941](https://github.com/rapidsai/cudf/pull/19941)) [@mroeschke](https://github.com/mroeschke)
- Move groupby benchmarks to nvbench ([#19930](https://github.com/rapidsai/cudf/pull/19930)) [@davidwendt](https://github.com/davidwendt)
- Perform more input validation in cuDF classic APIs ([#19929](https://github.com/rapidsai/cudf/pull/19929)) [@mroeschke](https://github.com/mroeschke)
- update nvidia-ml-py (&gt;=12), use cuda-toolkit wheels ([#19927](https://github.com/rapidsai/cudf/pull/19927)) [@jameslamb](https://github.com/jameslamb)
- Fill missing values in `Series/Index.values` for numeric types with np.nan by default ([#19923](https://github.com/rapidsai/cudf/pull/19923)) [@mroeschke](https://github.com/mroeschke)
- Add `rmm-release-threshold` to pdsh benchmarks CLI ([#19918](https://github.com/rapidsai/cudf/pull/19918)) [@TomAugspurger](https://github.com/TomAugspurger)
- Also use the CUDA 12 container for nightlies ([#19917](https://github.com/rapidsai/cudf/pull/19917)) [@vyasr](https://github.com/vyasr)
- Move test_binops.py to new cuDF classic directory structure ([#19914](https://github.com/rapidsai/cudf/pull/19914)) [@mroeschke](https://github.com/mroeschke)
- Eagerly load nvCOMP library in `cudf::initialize()` ([#19906](https://github.com/rapidsai/cudf/pull/19906)) [@vuule](https://github.com/vuule)
- Pin to CUDA 12 image for integration tests ([#19903](https://github.com/rapidsai/cudf/pull/19903)) [@vyasr](https://github.com/vyasr)
- Use branch-25.10 again ([#19902](https://github.com/rapidsai/cudf/pull/19902)) [@jameslamb](https://github.com/jameslamb)
- Disable test on non-default stream ([#19901](https://github.com/rapidsai/cudf/pull/19901)) [@vyasr](https://github.com/vyasr)
- Use cupy array instead of numba device array as inputs to jit routines ([#19897](https://github.com/rapidsai/cudf/pull/19897)) [@mroeschke](https://github.com/mroeschke)
- Remove deprecated `DataFrame.apply_rows`, deprecate `DataFrame.apply_chunks` and `Groupby.apply_grouped` ([#19896](https://github.com/rapidsai/cudf/pull/19896)) [@mroeschke](https://github.com/mroeschke)
- Move test_dataframe.py to new cuDF classic directory structure ([#19890](https://github.com/rapidsai/cudf/pull/19890)) [@mroeschke](https://github.com/mroeschke)
- Make sure conftest fixture data is valid on exit ([#19889](https://github.com/rapidsai/cudf/pull/19889)) [@vyasr](https://github.com/vyasr)
- Move test_index/multiindex/indexing.py to new cuDF classic directory structure ([#19887](https://github.com/rapidsai/cudf/pull/19887)) [@mroeschke](https://github.com/mroeschke)
- [FEA] Build CUDF with CCCL 3.1.0 ([#19886](https://github.com/rapidsai/cudf/pull/19886)) [@lamarrr](https://github.com/lamarrr)
- Coalesce IO of chunks with different compression when reading Parquet files ([#19884](https://github.com/rapidsai/cudf/pull/19884)) [@vuule](https://github.com/vuule)
- Update boost version to 1.79 for JNI dockerfile ([#19883](https://github.com/rapidsai/cudf/pull/19883)) [@pxLi](https://github.com/pxLi)
- Move test_categorical/dask/serialize.py to new cuDF classic test directory structure ([#19877](https://github.com/rapidsai/cudf/pull/19877)) [@mroeschke](https://github.com/mroeschke)
- Move prefetching out of experimental and simplify the API ([#19875](https://github.com/rapidsai/cudf/pull/19875)) [@vyasr](https://github.com/vyasr)
- Remove `diff.sh` and merge diff generation into `run.sh` ([#19871](https://github.com/rapidsai/cudf/pull/19871)) [@galipremsagar](https://github.com/galipremsagar)
- Remove pyarrow upper bound ([#19870](https://github.com/rapidsai/cudf/pull/19870)) [@vyasr](https://github.com/vyasr)
- Prevent installation of pytest-rerunfailures 16.0.0 ([#19863](https://github.com/rapidsai/cudf/pull/19863)) [@pentschev](https://github.com/pentschev)
- use &#39;nvidia-ml-py&#39; package for &#39;pynvml&#39; module ([#19862](https://github.com/rapidsai/cudf/pull/19862)) [@jameslamb](https://github.com/jameslamb)
- Avoid more direct construction of cuDF classic columns ([#19858](https://github.com/rapidsai/cudf/pull/19858)) [@mroeschke](https://github.com/mroeschke)
- Bump pandas supported version to `2.3.2` ([#19856](https://github.com/rapidsai/cudf/pull/19856)) [@galipremsagar](https://github.com/galipremsagar)
- Use cupy arrays instead of numba device arrays for cuDF classic intermediates ([#19855](https://github.com/rapidsai/cudf/pull/19855)) [@mroeschke](https://github.com/mroeschke)
- Move row operators to detail and deprecate legacy ([#19849](https://github.com/rapidsai/cudf/pull/19849)) [@PointKernel](https://github.com/PointKernel)
- Fix flaky DataFrame `to_string` test ([#19847](https://github.com/rapidsai/cudf/pull/19847)) [@brandon-b-miller](https://github.com/brandon-b-miller)
- Pin pytest-rerunfailures&lt;16 ([#19846](https://github.com/rapidsai/cudf/pull/19846)) [@mroeschke](https://github.com/mroeschke)
- revert numba CUDA 13 workaround ([#19842](https://github.com/rapidsai/cudf/pull/19842)) [@jameslamb](https://github.com/jameslamb)
- Avoid CategoricalColumn constructors in cuDF classic ([#19837](https://github.com/rapidsai/cudf/pull/19837)) [@mroeschke](https://github.com/mroeschke)
- Construct cuDF classic Decimal32/64Columns from RMM buffers ([#19834](https://github.com/rapidsai/cudf/pull/19834)) [@mroeschke](https://github.com/mroeschke)
- Avoid direct construction of cuDF classic columns ([#19829](https://github.com/rapidsai/cudf/pull/19829)) [@mroeschke](https://github.com/mroeschke)
- Support input filename in ndsh q01 benchmark ([#19820](https://github.com/rapidsai/cudf/pull/19820)) [@davidwendt](https://github.com/davidwendt)
- Run cudf-polars-polars-tests on changes in test_python file group ([#19819](https://github.com/rapidsai/cudf/pull/19819)) [@mroeschke](https://github.com/mroeschke)
- Remove test_mvc.py ([#19816](https://github.com/rapidsai/cudf/pull/19816)) [@mroeschke](https://github.com/mroeschke)
- pin oldest numpy in dask-cudf tests, update dependency floors (cuda-python 12.9.2, cupy 13.6.0, numba 0.60.0) ([#19806](https://github.com/rapidsai/cudf/pull/19806)) [@jameslamb](https://github.com/jameslamb)
- Remove iterative `nan` &amp; `nat` inefficient checks in `as_column` constructor ([#19804](https://github.com/rapidsai/cudf/pull/19804)) [@galipremsagar](https://github.com/galipremsagar)
- Simplify/consolidate from_arrow logic ([#19801](https://github.com/rapidsai/cudf/pull/19801)) [@mroeschke](https://github.com/mroeschke)
- Refactor column_empty to use only pylibcudf APIs ([#19800](https://github.com/rapidsai/cudf/pull/19800)) [@mroeschke](https://github.com/mroeschke)
- Use more cached_property where possible for Index and subclasses ([#19799](https://github.com/rapidsai/cudf/pull/19799)) [@mroeschke](https://github.com/mroeschke)
- Update rapids-dependency-file-generator ([#19796](https://github.com/rapidsai/cudf/pull/19796)) [@KyleFromNVIDIA](https://github.com/KyleFromNVIDIA)
- rearrange dependencies.yaml, other small changes ([#19794](https://github.com/rapidsai/cudf/pull/19794)) [@jameslamb](https://github.com/jameslamb)
- Update exception handling in pdsh benchmarks ([#19793](https://github.com/rapidsai/cudf/pull/19793)) [@TomAugspurger](https://github.com/TomAugspurger)
- Fix how nvcomp major version is extracted ([#19791](https://github.com/rapidsai/cudf/pull/19791)) [@KyleFromNVIDIA](https://github.com/KyleFromNVIDIA)
- Use KvikIO&#39;s unified interface to create remote I/O endpoints ([#19788](https://github.com/rapidsai/cudf/pull/19788)) [@kingcrimsontianyu](https://github.com/kingcrimsontianyu)
- Add object-oriented APIs for left semi- and anti- join (Part I) ([#19778](https://github.com/rapidsai/cudf/pull/19778)) [@shrshi](https://github.com/shrshi)
- Add nvbench benchmark for cudf::encode API ([#19777](https://github.com/rapidsai/cudf/pull/19777)) [@davidwendt](https://github.com/davidwendt)
- Some clarifications, improvements to GroupedRollingWindows in cudf-polars ([#19776](https://github.com/rapidsai/cudf/pull/19776)) [@Matt711](https://github.com/Matt711)
- Remove validation on import ([#19775](https://github.com/rapidsai/cudf/pull/19775)) [@vyasr](https://github.com/vyasr)
- Move more test_dataframe.py tests to new cudf classic testing directory ([#19770](https://github.com/rapidsai/cudf/pull/19770)) [@mroeschke](https://github.com/mroeschke)
- Build and test with CUDA 13.0.0 ([#19768](https://github.com/rapidsai/cudf/pull/19768)) [@jameslamb](https://github.com/jameslamb)
- Skip polars CPU perf test for with_columns ([#19763](https://github.com/rapidsai/cudf/pull/19763)) [@Matt711](https://github.com/Matt711)
- Optionally capture Shuffle Stats in cudf-polars pdsh benchmarks ([#19762](https://github.com/rapidsai/cudf/pull/19762)) [@TomAugspurger](https://github.com/TomAugspurger)
- Expand compression codec coverage in ORC and Parquet benchmarks ([#19760](https://github.com/rapidsai/cudf/pull/19760)) [@vuule](https://github.com/vuule)
- Add ``ColumnSourceInfo`` convenience layer ([#19752](https://github.com/rapidsai/cudf/pull/19752)) [@rjzamora](https://github.com/rjzamora)
- Support decimal columns in cudf_polars ([#19749](https://github.com/rapidsai/cudf/pull/19749)) [@mroeschke](https://github.com/mroeschke)
- Skip third-party tests when possible ([#19747](https://github.com/rapidsai/cudf/pull/19747)) [@vyasr](https://github.com/vyasr)
- Revert &quot;Support decimal columns in cudf_polars&quot; ([#19746](https://github.com/rapidsai/cudf/pull/19746)) [@mroeschke](https://github.com/mroeschke)
- Vendor libnvcomp in libcudf ([#19743](https://github.com/rapidsai/cudf/pull/19743)) [@bdice](https://github.com/bdice)
- Remove outdated numba workarounds ([#19738](https://github.com/rapidsai/cudf/pull/19738)) [@bdice](https://github.com/bdice)
- Move test_buffer/column/column_accesor/cuda_apply.py to new cudf classic testing directory ([#19737](https://github.com/rapidsai/cudf/pull/19737)) [@mroeschke](https://github.com/mroeschke)
- Move more test_dataframe.py tests to new cudf classic testing directory ([#19731](https://github.com/rapidsai/cudf/pull/19731)) [@mroeschke](https://github.com/mroeschke)
- Move test_udf_masked_ops/test_dropna to new cudf classic testing directory ([#19730](https://github.com/rapidsai/cudf/pull/19730)) [@mroeschke](https://github.com/mroeschke)
- Move test_numerical/{numpy|pandas}_interop/setitem.py to new cudf classic testing directory ([#19725](https://github.com/rapidsai/cudf/pull/19725)) [@mroeschke](https://github.com/mroeschke)
- Move test_timedelta/string/sorting/list/datetime.py to new cudf classic directory structure ([#19723](https://github.com/rapidsai/cudf/pull/19723)) [@mroeschke](https://github.com/mroeschke)
- Warn on fallback in the streaming tests in cudf-polars ([#19721](https://github.com/rapidsai/cudf/pull/19721)) [@Matt711](https://github.com/Matt711)
- Optionally print shuffle stats in pdsh benchmarks ([#19719](https://github.com/rapidsai/cudf/pull/19719)) [@TomAugspurger](https://github.com/TomAugspurger)
- Move test_{io}.py files to new cudf classic test directory ([#19709](https://github.com/rapidsai/cudf/pull/19709)) [@mroeschke](https://github.com/mroeschke)
- Move to pyarrow and numpy to run_constrained ([#19706](https://github.com/rapidsai/cudf/pull/19706)) [@vyasr](https://github.com/vyasr)
- Remove unreachable code in rapidsmpf shuffle ([#19704](https://github.com/rapidsai/cudf/pull/19704)) [@TomAugspurger](https://github.com/TomAugspurger)
- Moves test_options to cudf testing directory, clean up old, stubbed testing files in directory ([#19698](https://github.com/rapidsai/cudf/pull/19698)) [@mroeschke](https://github.com/mroeschke)
- Move (most of) test_index.py to new cudf classic directory structure ([#19696](https://github.com/rapidsai/cudf/pull/19696)) [@mroeschke](https://github.com/mroeschke)
- Improve `M2`, `VARIANCE` and `STD` hash-based groupby aggregations ([#19694](https://github.com/rapidsai/cudf/pull/19694)) [@ttnghia](https://github.com/ttnghia)
- Move quantiles libcudf benchmark to nvbench ([#19692](https://github.com/rapidsai/cudf/pull/19692)) [@davidwendt](https://github.com/davidwendt)
- Handle `TIMESTAMP_DAYS` in rolling window offsets ([#19689](https://github.com/rapidsai/cudf/pull/19689)) [@Matt711](https://github.com/Matt711)
- Move test_groupby to new cudf classic directory structure ([#19688](https://github.com/rapidsai/cudf/pull/19688)) [@mroeschke](https://github.com/mroeschke)
- Move some of test_dataframe.py to new cudf classic directory structure ([#19687](https://github.com/rapidsai/cudf/pull/19687)) [@mroeschke](https://github.com/mroeschke)
- Change nvtext::character_tokenize to return a list column ([#19685](https://github.com/rapidsai/cudf/pull/19685)) [@davidwendt](https://github.com/davidwendt)
- Split up rolling.cuh into separate headers ([#19682](https://github.com/rapidsai/cudf/pull/19682)) [@davidwendt](https://github.com/davidwendt)
- Move test_factorize/drop_duplicates.py to new cudf classic test directory ([#19681](https://github.com/rapidsai/cudf/pull/19681)) [@mroeschke](https://github.com/mroeschke)
- Move test_offset/repr.py to new cudf classic testing directory ([#19677](https://github.com/rapidsai/cudf/pull/19677)) [@mroeschke](https://github.com/mroeschke)
- Move test_stats/reductions/quantile and misc to new cudf classic testing directory ([#19675](https://github.com/rapidsai/cudf/pull/19675)) [@mroeschke](https://github.com/mroeschke)
- Cache hash values to improve hash-based groupby performance with wide/complex table keys ([#19670](https://github.com/rapidsai/cudf/pull/19670)) [@ttnghia](https://github.com/ttnghia)
- Move test_interval/test_dtypes/test_rank.py to new cudf directory structure ([#19668](https://github.com/rapidsai/cudf/pull/19668)) [@mroeschke](https://github.com/mroeschke)
- Clean and move test_join_order/interpolate/onehot.py to new cudf classic test directory structure ([#19662](https://github.com/rapidsai/cudf/pull/19662)) [@mroeschke](https://github.com/mroeschke)
- Migrate mixed join to use multiset ([#19660](https://github.com/rapidsai/cudf/pull/19660)) [@PointKernel](https://github.com/PointKernel)
- Run pylibcudf tests without its optional dependencies ([#19657](https://github.com/rapidsai/cudf/pull/19657)) [@vyasr](https://github.com/vyasr)
- Use build cluster in devcontainers ([#19652](https://github.com/rapidsai/cudf/pull/19652)) [@trxcllnt](https://github.com/trxcllnt)
- Use rapids_cuda_enable_fatbin_compression ([#19650](https://github.com/rapidsai/cudf/pull/19650)) [@robertmaynard](https://github.com/robertmaynard)
- Re-enable Disabled Join Tests ([#19649](https://github.com/rapidsai/cudf/pull/19649)) [@PointKernel](https://github.com/PointKernel)
- Use public Arrow functions for TDigest in PercentileApproxInputTypesTests ([#19648](https://github.com/rapidsai/cudf/pull/19648)) [@davidwendt](https://github.com/davidwendt)
- Use cudaDeviceGetAttribute to get ComputeMode for CUDA13 ([#19645](https://github.com/rapidsai/cudf/pull/19645)) [@GaryShen2008](https://github.com/GaryShen2008)
- remove initial memset of values in parquet reader ([#19643](https://github.com/rapidsai/cudf/pull/19643)) [@pmattione-nvidia](https://github.com/pmattione-nvidia)
- Move ~half of test_groupby.py to new cudf classic test directory structure ([#19640](https://github.com/rapidsai/cudf/pull/19640)) [@mroeschke](https://github.com/mroeschke)
- Move test_csv/feather/json.py to new cudf classic test directory structure ([#19639](https://github.com/rapidsai/cudf/pull/19639)) [@mroeschke](https://github.com/mroeschke)
- Move test_array_function/ufunc to new cudf classic test directory structure ([#19637](https://github.com/rapidsai/cudf/pull/19637)) [@mroeschke](https://github.com/mroeschke)
- Fix anchor naming conventions in dependencies.yaml ([#19635](https://github.com/rapidsai/cudf/pull/19635)) [@KyleFromNVIDIA](https://github.com/KyleFromNVIDIA)
- Require `--scale` for PDS-DS benchmarks (due to nonlinear scaling) ([#19631](https://github.com/rapidsai/cudf/pull/19631)) [@Matt711](https://github.com/Matt711)
- Move test_replace.py to new cudf classic directory structure ([#19629](https://github.com/rapidsai/cudf/pull/19629)) [@mroeschke](https://github.com/mroeschke)
- Move test_concat/test_reductions.py to new cudf classic directory structure ([#19626](https://github.com/rapidsai/cudf/pull/19626)) [@mroeschke](https://github.com/mroeschke)
- Update rapids_config to handle user defined branch name ([#19623](https://github.com/rapidsai/cudf/pull/19623)) [@robertmaynard](https://github.com/robertmaynard)
- Add nvtx ranges to public APIs of the experimental parquet reader ([#19618](https://github.com/rapidsai/cudf/pull/19618)) [@mhaseeb123](https://github.com/mhaseeb123)
- Move test_resampling/query/pickling to new cudf classic directory structure ([#19615](https://github.com/rapidsai/cudf/pull/19615)) [@mroeschke](https://github.com/mroeschke)
- Move test_reshape.py to new cudf classic directory strucutre, remove reshape._merge_sorted ([#19614](https://github.com/rapidsai/cudf/pull/19614)) [@mroeschke](https://github.com/mroeschke)
- Move test_rolling/ewm.py to new cudf classic directory structure ([#19611](https://github.com/rapidsai/cudf/pull/19611)) [@mroeschke](https://github.com/mroeschke)
- Simplify cudf::scalar usage in reduce utility ([#19608](https://github.com/rapidsai/cudf/pull/19608)) [@davidwendt](https://github.com/davidwendt)
- Update to numba-cuda&gt;=0.18.0,&lt;0.19.0 ([#19604](https://github.com/rapidsai/cudf/pull/19604)) [@bdice](https://github.com/bdice)
- Update spark-rapdis-jni action to use PR&#39;s base.ref and fix issue of ccache version in dockerfile ([#19603](https://github.com/rapidsai/cudf/pull/19603)) [@pxLi](https://github.com/pxLi)
- Multithreaded CPU algorithm for data page mask computation ([#19602](https://github.com/rapidsai/cudf/pull/19602)) [@mhaseeb123](https://github.com/mhaseeb123)
- Move test_cuda_array_interface/cut/dataframe_copy.py to new cudf classic test directories ([#19599](https://github.com/rapidsai/cudf/pull/19599)) [@mroeschke](https://github.com/mroeschke)
- Support decimal columns in cudf_polars ([#19589](https://github.com/rapidsai/cudf/pull/19589)) [@mroeschke](https://github.com/mroeschke)
- Preserve decimal precision in `cudf::interop::column_metadata` ([#19587](https://github.com/rapidsai/cudf/pull/19587)) [@mroeschke](https://github.com/mroeschke)
- Always use strict zipping ([#19584](https://github.com/rapidsai/cudf/pull/19584)) [@vyasr](https://github.com/vyasr)
- Pin polars version to &lt;1.33 ([#19582](https://github.com/rapidsai/cudf/pull/19582)) [@Matt711](https://github.com/Matt711)
- ci(labeler): update labeler action to [@v5 ([#19581](https://github.com/rapidsai/cudf/pull/19581)) @gforsyth](https://github.com/v5 ([#19581](https://github.com/rapidsai/cudf/pull/19581)) @gforsyth)
- Update rapids-build-backend to 0.4.0 ([#19580](https://github.com/rapidsai/cudf/pull/19580)) [@KyleFromNVIDIA](https://github.com/KyleFromNVIDIA)
- Move (most of) test_list.py to new cudf classic test directories ([#19574](https://github.com/rapidsai/cudf/pull/19574)) [@mroeschke](https://github.com/mroeschke)
- Move test_monotonic.py to new cudf classic test directory structure ([#19572](https://github.com/rapidsai/cudf/pull/19572)) [@mroeschke](https://github.com/mroeschke)
- Additional gtests error checks for string/timestamp convert libcudf APIs ([#19562](https://github.com/rapidsai/cudf/pull/19562)) [@davidwendt](https://github.com/davidwendt)
- Avoid cudf.pandas fallback for `pandas.array.NumpyExtensionArray` of strings ([#19558](https://github.com/rapidsai/cudf/pull/19558)) [@mroeschke](https://github.com/mroeschke)
- Move str accessor tests in test_string.py to new cudf classic test directory structure ([#19557](https://github.com/rapidsai/cudf/pull/19557)) [@mroeschke](https://github.com/mroeschke)
- Rework fill/repeat benchmark to use nvbench ([#19556](https://github.com/rapidsai/cudf/pull/19556)) [@davidwendt](https://github.com/davidwendt)
- Use no_validity() instead of null_probability(0) in benchmarks profile ([#19554](https://github.com/rapidsai/cudf/pull/19554)) [@davidwendt](https://github.com/davidwendt)
- Move (most of) test_timedelta.py and test_struct.py to new cudf classic test directory structure ([#19551](https://github.com/rapidsai/cudf/pull/19551)) [@mroeschke](https://github.com/mroeschke)
- Capture commit hashes in pdsh benchmarks ([#19548](https://github.com/rapidsai/cudf/pull/19548)) [@TomAugspurger](https://github.com/TomAugspurger)
- Simplify clang dependency spec ([#19546](https://github.com/rapidsai/cudf/pull/19546)) [@vyasr](https://github.com/vyasr)
- Move timeout in cudf.pandas pandas unit tests script to ci script ([#19542](https://github.com/rapidsai/cudf/pull/19542)) [@mroeschke](https://github.com/mroeschke)
- [FEA] Refactor AST `operator_functor`s for use in JIT-compiled CUDA ([#19541](https://github.com/rapidsai/cudf/pull/19541)) [@lamarrr](https://github.com/lamarrr)
- Construct cuDF classic columns with __array_interface__ through pylibcudf ([#19538](https://github.com/rapidsai/cudf/pull/19538)) [@mroeschke](https://github.com/mroeschke)
- Separate row mask and page mask computation and usage ([#19537](https://github.com/rapidsai/cudf/pull/19537)) [@mhaseeb123](https://github.com/mhaseeb123)
- Get rid of CG logic in the mixed semi-join kernel ([#19536](https://github.com/rapidsai/cudf/pull/19536)) [@PointKernel](https://github.com/PointKernel)
- Construct more cuDF classic Columns with pylibcudf instead of using Buffers ([#19535](https://github.com/rapidsai/cudf/pull/19535)) [@mroeschke](https://github.com/mroeschke)
- Fix clang-tools version pinning ([#19529](https://github.com/rapidsai/cudf/pull/19529)) [@wence-](https://github.com/wence-)
- Add cudf_polars unit test for `is_in([])` expr ([#19525](https://github.com/rapidsai/cudf/pull/19525)) [@mroeschke](https://github.com/mroeschke)
- Expose `nvtext::letter_type` to python ([#19520](https://github.com/rapidsai/cudf/pull/19520)) [@Matt711](https://github.com/Matt711)
- Remove c++ stringview interop example ([#19516](https://github.com/rapidsai/cudf/pull/19516)) [@davidwendt](https://github.com/davidwendt)
- Remove cudf/_fuzz_testing directory ([#19510](https://github.com/rapidsai/cudf/pull/19510)) [@mroeschke](https://github.com/mroeschke)
- Add missing import of pyarrow.parquet when reading specified row_groups. ([#19509](https://github.com/rapidsai/cudf/pull/19509)) [@bdice](https://github.com/bdice)
- Don&#39;t run serial cudf_pandas tests when testing multiple pandas versions ([#19507](https://github.com/rapidsai/cudf/pull/19507)) [@mroeschke](https://github.com/mroeschke)
- Clean testing/_utils.py ([#19506](https://github.com/rapidsai/cudf/pull/19506)) [@mroeschke](https://github.com/mroeschke)
- Move some test_datetime.py tests to new cudf classic test directory structure ([#19505](https://github.com/rapidsai/cudf/pull/19505)) [@mroeschke](https://github.com/mroeschke)
- Move test_joining to new cudf classic test directory structure ([#19501](https://github.com/rapidsai/cudf/pull/19501)) [@mroeschke](https://github.com/mroeschke)
- Upgrade `gcc-toolset` for Java/JNI build to version 14 ([#19500](https://github.com/rapidsai/cudf/pull/19500)) [@ttnghia](https://github.com/ttnghia)
- Remove deprecated subword-tokenizer APIs ([#19498](https://github.com/rapidsai/cudf/pull/19498)) [@davidwendt](https://github.com/davidwendt)
- Move some test_multiindex.py to new cudf classic test directory structure ([#19496](https://github.com/rapidsai/cudf/pull/19496)) [@mroeschke](https://github.com/mroeschke)
- Add nvtx ranges and minor fix for `lists` types in the next-gen parquet reader ([#19493](https://github.com/rapidsai/cudf/pull/19493)) [@mhaseeb123](https://github.com/mhaseeb123)
- Move test_search/test_scan/test_seriesmap.py to new cudf classic test directory structure ([#19492](https://github.com/rapidsai/cudf/pull/19492)) [@mroeschke](https://github.com/mroeschke)
- Improve support for sliced input on from_arrow_host APIs ([#19491](https://github.com/rapidsai/cudf/pull/19491)) [@davidwendt](https://github.com/davidwendt)
- Move test_avro/test_api_types.py and some DataFrame tests to new cudf classic test directory structure ([#19490](https://github.com/rapidsai/cudf/pull/19490)) [@mroeschke](https://github.com/mroeschke)
- Move test_series.py to new cudf classic test directory structure ([#19485](https://github.com/rapidsai/cudf/pull/19485)) [@mroeschke](https://github.com/mroeschke)
- Move test_testing.py to new cudf classic test directory structure ([#19481](https://github.com/rapidsai/cudf/pull/19481)) [@mroeschke](https://github.com/mroeschke)
- Allow latest OS in devcontainers ([#19480](https://github.com/rapidsai/cudf/pull/19480)) [@bdice](https://github.com/bdice)
- Move test_unaops/test_unique/test_transform.py to new cudf classic test directory structure ([#19477](https://github.com/rapidsai/cudf/pull/19477)) [@mroeschke](https://github.com/mroeschke)
- Branch 25.10 merge branch 25.08 ([#19475](https://github.com/rapidsai/cudf/pull/19475)) [@davidwendt](https://github.com/davidwendt)
- Use more pytest fixtures and clean data files cuDF classic tests subdirectories ([#19474](https://github.com/rapidsai/cudf/pull/19474)) [@mroeschke](https://github.com/mroeschke)
- Use more pytest fixtures and avoid GPU parameterization in test_binops/column/column_accessor/contains.py and more ([#19473](https://github.com/rapidsai/cudf/pull/19473)) [@mroeschke](https://github.com/mroeschke)
- Use more pytest fixtures and avoid GPU parameterization in test_csv/cuda_*/cut.py and more ([#19463](https://github.com/rapidsai/cudf/pull/19463)) [@mroeschke](https://github.com/mroeschke)
- Improve readability when printing pylibcudf enums ([#19451](https://github.com/rapidsai/cudf/pull/19451)) [@Matt711](https://github.com/Matt711)
- Use more pytest fixtures and avoid GPU parameterization in cuDF classic tests ([#19450](https://github.com/rapidsai/cudf/pull/19450)) [@mroeschke](https://github.com/mroeschke)
- Use more pytest fixtures and avoid GPU parameterization in test_dropna/factorize.py and more ([#19449](https://github.com/rapidsai/cudf/pull/19449)) [@mroeschke](https://github.com/mroeschke)
- Update build infra to support new branching strategy ([#19445](https://github.com/rapidsai/cudf/pull/19445)) [@robertmaynard](https://github.com/robertmaynard)
- Updated libcudf-example conda package to preserve directories structure ([#19440](https://github.com/rapidsai/cudf/pull/19440)) [@Avinash-Raj](https://github.com/Avinash-Raj)
- Use more pytest fixtures and avoid GPU parameterization in test_groupby/index.py ([#19438](https://github.com/rapidsai/cudf/pull/19438)) [@mroeschke](https://github.com/mroeschke)
- Use more pytest fixtures and avoid GPU parameterization in test_indexing/joining/monotonic/multiindex.py ([#19437](https://github.com/rapidsai/cudf/pull/19437)) [@mroeschke](https://github.com/mroeschke)
- Use more pytest fixtures and avoid GPU parameterization in cuDF classic tests ([#19436](https://github.com/rapidsai/cudf/pull/19436)) [@mroeschke](https://github.com/mroeschke)
- Use more pytest fixtures and avoid GPU parameterization in test_query/rank/reduction/repr.py ([#19434](https://github.com/rapidsai/cudf/pull/19434)) [@mroeschke](https://github.com/mroeschke)
- Use more pytest fixtures and avoid GPU parameterization in test_replace/reshape/rolling.py ([#19426](https://github.com/rapidsai/cudf/pull/19426)) [@mroeschke](https://github.com/mroeschke)
- Update s3 Bucket fixture creation in test_s3 ([#19424](https://github.com/rapidsai/cudf/pull/19424)) [@mroeschke](https://github.com/mroeschke)
- Use more pytest fixtures and avoid GPU parameterization in cuDF classic tests ([#19419](https://github.com/rapidsai/cudf/pull/19419)) [@mroeschke](https://github.com/mroeschke)
- Fix various pandas test failures in `cudf.pandas` ([#19372](https://github.com/rapidsai/cudf/pull/19372)) [@galipremsagar](https://github.com/galipremsagar)
- Pin Narwhals to 1.47 ([#19358](https://github.com/rapidsai/cudf/pull/19358)) [@Matt711](https://github.com/Matt711)
- Run cudf-polars tests with all supported polars versions ([#19353](https://github.com/rapidsai/cudf/pull/19353)) [@Matt711](https://github.com/Matt711)
- Update `pandas-tests-diff` to only display GPU/CPU usage metrics ([#19210](https://github.com/rapidsai/cudf/pull/19210)) [@galipremsagar](https://github.com/galipremsagar)
- Use GCC 14 in conda builds. ([#19192](https://github.com/rapidsai/cudf/pull/19192)) [@vyasr](https://github.com/vyasr)
- Use KvikIO&#39;s implementation of file-backed memory mapping ([#19164](https://github.com/rapidsai/cudf/pull/19164)) [@kingcrimsontianyu](https://github.com/kingcrimsontianyu)
- Replace `rmm::device_scalar` with `cudf::detail::device_scalar` due to unnecessary synchronization (Part 3 of miss-sync) ([#19119](https://github.com/rapidsai/cudf/pull/19119)) [@JigaoLuo](https://github.com/JigaoLuo)
- Implement distributed sorted for ``cudf_polars`` ([#18912](https://github.com/rapidsai/cudf/pull/18912)) [@seberg](https://github.com/seberg)

# cudf 25.08.00 (6 Aug 2025)
# >>>>>>> END NEW CODE (76c36039df)

    Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
-->

# Changelog for hipDF

Documentation for hipDF is available at
[https://rocm.docs.amd.com/projects/hipDF/en/latest/](https://rocm.docs.amd.com/projects/hipDF/en/latest/).

## hipDF 3.0.0 for ROCm-DS 26.03

### Added

 * Major upgrade aligning hipDF APIs with RAPIDS cuDF 25.10 APIs (from 25.02). For detailed upstream changes, see the [original changelog](CHANGELOG_UPSTREAM_CUDF.md)
 * Added pylibhipdf wrapper module providing Python bindings compatible with upstream pylibcudf
 * Added support for gfx950 GPU architecture
 * Added experimental support for gfx11*/gfx12* RDNA architectures (gfx1100, gfx1101, gfx1200, gfx1201)
 * Added hipcomp zstd GPU decompression support for ORC and Parquet file formats

### Known limitations and notes
 * DEBUG builds with -O0 optimization are not currently supported. Use -Og or higher for DEBUG builds (default setting). Support for -O0 is planned in a future toolchain update.
 * When using the cudf.pandas acceleration layer with XNACK enabled and workloads that significantly exceed physical GPU VRAM (oversubscription), some systems may exhibit instability or reduced performance under heavy memory pressure.
 * Using the cudf.pandas acceleration layer with XNACK disabled (`HSA_XNACK=0`) can trigger instabilities.

## hipDF 2.0.0 for ROCm-DS 25.10

### Added

 * Major upgrade aligning hipDF APIs with RAPIDS cuDF 25.02 APIs. For the detailed changes, see the [original changelog](CHANGELOG_UPSTREAM_CUDF.md)

### Known limitations and notes
 * DEBUG builds with -O0 optimization are not currently supported. Use -Og or higher for DEBUG builds (default setting). Support for -O0 is planned in a future toolchain update.
 * When using the cudf.pandas acceleration layer with XNACK enabled and workloads that significantly exceed physical GPU VRAM (oversubscription), some systems may exhibit instability or reduced performance under heavy memory pressure.
 * Using the cudf.pandas acceleration layer with XNACK disabled (`HSA_XNACK=0`) can trigger instabilities.

## hipDF 1.0.0b1 for ROCm-DS 25.05

### Added

* Initial release based on cuDF 23.10.
