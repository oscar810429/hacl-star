#ifndef _BENCH_HASH_H_
#define _BENCH_HASH_H_

void bench_md5(const BenchmarkSettings & s);
void bench_sha1(const BenchmarkSettings & s);
void bench_sha2(const BenchmarkSettings & s);
void bench_sha2_224(const BenchmarkSettings & s);
void bench_sha2_256(const BenchmarkSettings & s);
void bench_sha2_384(const BenchmarkSettings & s);
void bench_sha2_512(const BenchmarkSettings & s);
void bench_hash(const BenchmarkSettings & s);

#endif