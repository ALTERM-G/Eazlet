#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <utility>
#include <vector>

extern "C" {

static const char* DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

using u64 = uint64_t;
using i64 = int64_t;
using u128 = unsigned __int128;

static inline u64 mul_mod(u64 a, u64 b, u64 mod) {
    return (u64)((u128)a * (u128)b % (u128)mod);
}

static inline u64 pow_mod(u64 base, u64 exp, u64 mod) {
    u64 result = 1 % mod;
    base %= mod;
    while (exp) {
        if (exp & 1) result = mul_mod(result, base, mod);
        base = mul_mod(base, base, mod);
        exp >>= 1;
    }
    return result;
}

static inline u64 gcd_u(u64 a, u64 b) {
    while (b) { u64 t = a % b; a = b; b = t; }
    return a;
}

static bool is_prime(u64 n) {
    if (n < 2) return false;
    for (u64 p : {2ULL,3ULL,5ULL,7ULL,11ULL,13ULL,17ULL,19ULL,23ULL,29ULL,31ULL,37ULL}) {
        if (n == p) return true;
        if (n % p == 0) return false;
    }
    u64 d = n - 1, s = 0;
    while ((d & 1) == 0) { d >>= 1; ++s; }
    for (u64 a : {2ULL,325ULL,9375ULL,28178ULL,450775ULL,9780504ULL,1795265022ULL}) {
        if (a % n == 0) continue;
        u64 x = pow_mod(a, d, n);
        if (x == 1 || x == n - 1) continue;
        bool comp = true;
        for (u64 r = 1; r < s; ++r) {
            x = mul_mod(x, x, n);
            if (x == n - 1) { comp = false; break; }
        }
        if (comp) return false;
    }
    return true;
}

static u64 pollard_rho(u64 n) {
    if ((n & 1ULL) == 0) return 2;
    if (n % 3ULL == 0) return 3;
    u64 y = 2, c = 1, m = 2;
    u64 g = 1, r = 1, q = 1, ys = 0, x = 0;
    while (g == 1) {
        x = y;
        for (u64 i = 0; i < r; ++i) y = (mul_mod(y, y, n) + c) % n;
        u64 k = 0;
        while (k < r && g == 1) {
            ys = y;
            u64 lim = (m < (r - k)) ? m : (r - k);
            for (u64 i = 0; i < lim; ++i) {
                y = (mul_mod(y, y, n) + c) % n;
                u64 diff = x > y ? x - y : y - x;
                q = mul_mod(q, diff, n);
            }
            g = gcd_u(q, n);
            k += m;
        }
        r <<= 1;
        if (r > (1ULL << 18)) {
            y = (y + 1) % n; c = (c + 3) % n; if (c == 0) c = 1; r = 1; g = 1; q = 1; m = 2;
        }
    }
    if (g == n) {
        do {
            ys = (mul_mod(ys, ys, n) + c) % n;
            u64 diff = x > ys ? x - ys : ys - x;
            g = gcd_u(diff, n);
        } while (g == 1);
    }
    return g;
}

static void factor_rec(u64 n, std::vector<u64>& out) {
    if (n == 1) return;
    if (is_prime(n)) { out.push_back(n); return; }
    u64 d = pollard_rho(n);
    if (d == n) {
        for (u64 c = 2; c < 200 && d == n; ++c) {
            u64 x = 2, y = 2, g = 1;
            auto f = [&](u64 v){ return (mul_mod(v,v,n)+c)%n; };
            while (g == 1) { x = f(x); y = f(f(y)); u64 diff = x>y?x-y:y-x; g = gcd_u(diff,n); }
            if (g != n) d = g;
        }
    }
    if (d == n || d == 0) { out.push_back(n); return; }
    factor_rec(d, out);
    factor_rec(n / d, out);
}

i64 nt_gcd(i64 a, i64 b) {
    u64 ua = a < 0 ? (u64)(-(a + 1)) + 1u : (u64)a;
    u64 ub = b < 0 ? (u64)(-(b + 1)) + 1u : (u64)b;
    return (i64)gcd_u(ua, ub);
}

i64 nt_lcm(i64 a, i64 b) {
    u64 ua = a < 0 ? (u64)(-(a + 1)) + 1u : (u64)a;
    u64 ub = b < 0 ? (u64)(-(b + 1)) + 1u : (u64)b;
    if (ua == 0 || ub == 0) return 0;
    u64 g = gcd_u(ua, ub);
    u128 r = (u128)(ua / g) * (u128)ub;
    if (r > (u128)INT64_MAX) return INT64_MAX;
    return (i64)r;
}

i64 nt_bezout(i64 a, i64 b, i64* x, i64* y) {
    i64 old_r = a, r = b;
    i64 old_s = 1, s = 0;
    i64 old_t = 0, t = 1;
    while (r != 0) {
        i64 q = old_r / r;
        i64 tmp;
        tmp = old_r - q * r; old_r = r; r = tmp;
        tmp = old_s - q * s; old_s = s; s = tmp;
        tmp = old_t - q * t; old_t = t; t = tmp;
    }
    if (old_r < 0) { old_r = -old_r; old_s = -old_s; old_t = -old_t; }
    if (x) *x = old_s;
    if (y) *y = old_t;
    return old_r;
}

char* nt_format_base(i64 n, int base) {
    if (base < 2) base = 10;
    bool neg = n < 0;
    u64 un = neg ? (u64)(-(n + 1)) + 1u : (u64)n;
    if (un == 0) {
        char* s = (char*)malloc(2);
        if (s) { s[0] = '0'; s[1] = 0; }
        return s;
    }
    if (base == 10) {
        std::string r = std::to_string(n);
        char* s = (char*)malloc(r.size() + 1);
        if (s) memcpy(s, r.c_str(), r.size() + 1);
        return s;
    }
    if (base <= 62) {
        std::string out;
        while (un) { out.push_back(DIGITS[un % (u64)base]); un /= (u64)base; }
        if (neg) out.push_back('-');
        std::reverse(out.begin(), out.end());
        char* s = (char*)malloc(out.size() + 1);
        if (s) memcpy(s, out.c_str(), out.size() + 1);
        return s;
    }
    std::vector<std::string> vals;
    while (un) { vals.push_back(std::to_string(un % (u64)base)); un /= (u64)base; }
    std::string out = neg ? "-(" : "(";
    for (size_t i = vals.size(); i-- > 0;) { out += vals[i]; if (i) out += ' '; }
    out += ")_" + std::to_string(base);
    char* s = (char*)malloc(out.size() + 1);
    if (s) memcpy(s, out.c_str(), out.size() + 1);
    return s;
}

void nt_free(char* p) { free(p); }

struct FactorState {
    u64 orig;
    std::vector<std::pair<u64,int>> factors;
    std::vector<u64> cofactors;
    u64 trial_d;
    u64 trial_limit;
    int phase;
    bool done;
};

FactorState* nt_factor_create(i64 n) {
    auto* st = new FactorState();
    u64 un = n < 0 ? (u64)(-(n + 1)) + 1u : (u64)n;
    st->orig = un;
    st->trial_d = 2;
    st->trial_limit = 1000000ULL;
    st->phase = (un < 2) ? 2 : 0;
    st->done = (un < 2);
    st->cofactors.clear();
    st->cofactors.push_back(un);
    return st;
}

static void add_factor(FactorState* st, u64 p) {
    for (auto& f : st->factors) if (f.first == p) { f.second++; return; }
    st->factors.push_back({p, 1});
}

static void finalize_factors(FactorState* st) {
    std::sort(st->factors.begin(), st->factors.end());
    std::vector<std::pair<u64,int>> m;
    for (auto& f : st->factors) {
        if (!m.empty() && m.back().first == f.first) m.back().second += f.second;
        else m.push_back(f);
    }
    st->factors.swap(m);
    st->done = true;
    st->phase = 2;
}

double nt_factor_step(FactorState* st, i64 budget, int* done_out) {
    if (!st || st->done) { if (done_out) *done_out = 1; return 1.0; }
    i64 work = 0;
    if (st->phase == 0) {
        while (work < budget && !st->cofactors.empty()) {
            u64& n = st->cofactors.back();
            if (n <= 1) { st->cofactors.pop_back(); continue; }
            if (st->trial_d > st->trial_limit || st->trial_d * st->trial_d > n) {
                break;
            }
            if (n % st->trial_d == 0) {
                add_factor(st, st->trial_d);
                n /= st->trial_d;
            } else {
                st->trial_d = (st->trial_d == 2) ? 3 : (st->trial_d + 2);
            }
            ++work;
        }
        if (st->trial_d > st->trial_limit) {
            st->phase = 1;
        } else {
            bool need_more = false;
            for (auto n : st->cofactors) if (n > 1 && st->trial_d * st->trial_d <= n && st->trial_d <= st->trial_limit) { need_more = true; break; }
            if (!need_more) st->phase = 1;
        }
        if (st->phase == 1) {
            std::vector<u64> c2;
            for (auto n : st->cofactors) if (n > 1) c2.push_back(n);
            st->cofactors.swap(c2);
        }
    }
    if (st->phase == 1) {
        while (!st->cofactors.empty() && work < budget) {
            u64 n = st->cofactors.back();
            st->cofactors.pop_back();
            if (n <= 1) continue;
            std::vector<u64> ps;
            factor_rec(n, ps);
            for (auto p : ps) add_factor(st, p);
            work += 1000;
        }
        if (st->cofactors.empty()) finalize_factors(st);
    }
    if (st->done) { if (done_out) *done_out = 1; return 1.0; }
    if (done_out) *done_out = 0;
    double prog = 0.0;
    if (st->phase == 0) {
        prog = 0.15 * (double)st->trial_d / (double)(st->trial_limit ? st->trial_limit : 1);
        if (prog > 0.15) prog = 0.15;
    } else {
        prog = 0.15 + 0.84 * (1.0 / (1.0 + (double)st->cofactors.size()));
        if (prog > 0.99) prog = 0.99;
    }
    return prog;
}

int nt_factor_count(FactorState* st) { return st ? (int)st->factors.size() : 0; }
u64 nt_factor_prime(FactorState* st, int i) { return (st && i >= 0 && (size_t)i < st->factors.size()) ? st->factors[i].first : 0; }
int nt_factor_exp(FactorState* st, int i) { return (st && i >= 0 && (size_t)i < st->factors.size()) ? st->factors[i].second : 0; }
void nt_factor_destroy(FactorState* st) { delete st; }

int nt_factor_divisors(FactorState* st, u64* out, int max_out) {
    if (!st) return 0;
    std::vector<u64> divs = {1};
    for (auto& fe : st->factors) {
        u64 p = fe.first; int e = fe.second;
        size_t base = divs.size();
        u64 pe = 1;
        for (int k = 1; k <= e; ++k) {
            pe *= p;
            for (size_t i = 0; i < base; ++i) {
                u64 v = divs[i] * pe;
                divs.push_back(v);
                if ((int)divs.size() > max_out && max_out > 0 && (int)divs.size() > 200000) break;
            }
        }
        if ((int)divs.size() > 200000 && max_out > 0) {}
    }
    std::sort(divs.begin(), divs.end());
    int total = (int)divs.size();
    if (out && max_out > 0) {
        int n = total < max_out ? total : max_out;
        for (int i = 0; i < n; ++i) out[i] = divs[i];
    }
    return total;
}

int nt_divisors(i64 n, u64* out, int max_out) {
    u64 un = n < 0 ? (u64)(-(n + 1)) + 1u : (u64)n;
    if (un == 0) return 0;
    std::vector<u64> small, large;
    u64 d = 1;
    while (d * d <= un) {
        if (un % d == 0) {
            small.push_back(d);
            if (d * d != un) large.push_back(un / d);
        }
        ++d;
    }
    int total = (int)(small.size() + large.size());
    int k = 0;
    for (auto v : small) { if (k < max_out && out) out[k] = v; ++k; }
    for (auto it = large.rbegin(); it != large.rend(); ++it) { if (k < max_out && out) out[k] = *it; ++k; }
    return total;
}

}
