#include <bits/stdc++.h>

using namespace std;

#define _ << " " <<

const int CACHE_LINE_SIZE = 1 << 5;
const int CACHE_WAY = 2;
const int CACHE_SETS_COUNT = 1 << 4;
const int CACHE_SET_SIZE = 4;
const int CACHE_OFFSET_SIZE = 5;

const int DATA1_BUS_SIZE = 2;
const int DATA2_BUS_SIZE = 2;

//int8 a[M][K];
//int16 b[K][N];
//int32 c[M][N];

const int M = 64;
const int N = 60;
const int K = 32;

const int A_STEP = 1;
const int B_STEP = 2;
const int C_STEP = 4;

const int A = 0;
const int B = M * K * A_STEP;
const int C = B + K * N * B_STEP;

int timer = 1;

int cache_tags[CACHE_SETS_COUNT][CACHE_WAY];
int cache_times[CACHE_SETS_COUNT][CACHE_WAY];
int cache_valid[CACHE_SETS_COUNT][CACHE_WAY];
int cache_dirty[CACHE_SETS_COUNT][CACHE_WAY];

int tacts_counter = 0;

int cache_miss = 0;
int cache_hit = 0;

bool check_entry(int set_num, int tag, bool write) {
    for (int i = 0; i < CACHE_WAY; ++i) {
        if (cache_tags[set_num][i] == tag) {
            cache_times[set_num][i] = timer++;
            if (write) cache_dirty[set_num][i] = 1;
            return true;
        }
    }
    return false;
}

void cache_replacement(int set_num, int tag, bool write) {
    int imn = 0;
    for (int i = 0; i < CACHE_WAY; ++i) {
        if (cache_valid[set_num][i] == 0 || cache_times[set_num][i] < cache_times[set_num][imn]) {
            imn = i;
        }
    }
    cache_times[set_num][imn] = timer++;
    if (cache_dirty[set_num][imn] == 1) {
        tacts_counter += 101;
    }
    cache_valid[set_num][imn] = 1;
    cache_dirty[set_num][imn] = 0;
    if (write) cache_dirty[set_num][imn] = 1;
    cache_tags[set_num][imn] = tag;
}

void memory_request(int addr, int bytes, bool write) {
    addr = addr >> CACHE_OFFSET_SIZE;
    int set_num = addr % (1 << CACHE_SET_SIZE);
    int tag = addr >> CACHE_SET_SIZE;

    if (check_entry(set_num, tag, write)) {
        tacts_counter += 7 + (bytes + 1) / 2;
        cache_hit++;
    } else {
        cache_miss++;
        cache_replacement(set_num, tag, write);
        tacts_counter += 106 + CACHE_LINE_SIZE / DATA2_BUS_SIZE + (bytes + 1) / 2;
    }
}

void process() {
    for (int i = 0; i < CACHE_SETS_COUNT; ++i) {
        for (int j = 0; j < CACHE_WAY; ++j) {
            cache_tags[i][j] = -1;
        }
    }
//    int8 *pa = a;
    int pa = A;
    tacts_counter++;
//    int32 *pc = c;
    int pc = C;
    tacts_counter++;

    tacts_counter++; // int y = 0
    for (int y = 0; y < M; y++)
    {
        tacts_counter++; // int x = 0
        for (int x = 0; x < N; x++)
        {
//            int16 *pb = b;
            int pb = B;
            tacts_counter++;
//            int32 s = 0;
            tacts_counter++;

            tacts_counter++; // int k = 0;
            for (int k = 0; k < K; k++)
            {
//                s += pa[k] * pb[x];
                tacts_counter++; // +=

                tacts_counter += 5; // *

                tacts_counter++; // pa + k
                memory_request(pa + A_STEP * k, A_STEP, 0);

                tacts_counter++; // pb + x;
                memory_request(pb + B_STEP * x, B_STEP, 0);

                pb += N * B_STEP;
                tacts_counter++;

                tacts_counter++; // k++
            }
//            pc[x] = s;
            tacts_counter++; // pc + x
            memory_request(pc + C_STEP * x, C_STEP, 1);

            tacts_counter++; // x++
        }
        pa += K * A_STEP;
        tacts_counter++;

        pc += N * C_STEP;
        tacts_counter++;

        tacts_counter++; // y++
    }
    tacts_counter++; //ret
}

signed main() {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);
    cout.tie(nullptr);

    process();

    cout << "Memory request count:" _ cache_miss + cache_hit << endl;
    cout << "Cache miss:" _ cache_miss << endl;
    cout << "Cache hit:" _ cache_hit << endl;
    cout << fixed << setprecision(4) << "Statistic:" _
    (double)cache_hit / (double)(cache_hit + cache_miss) * 100 << "%" << endl;
    cout << "Tacts count:" _ tacts_counter << endl;
}