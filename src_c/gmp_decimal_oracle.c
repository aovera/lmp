#include <lua.h>
#include <lauxlib.h>
#include <gmp.h>
#include <stdlib.h>
#include <string.h>

static void mpz_mul_10_pow(mpz_t rop, const mpz_t op, unsigned long exp) {
    mpz_t pow10;
    mpz_init(pow10);
    mpz_ui_pow_ui(pow10, 10, exp);
    mpz_mul(rop, op, pow10);
    mpz_clear(pow10);
}

// String converter
static char* format_decimal_exact(const mpz_t mantissa, long scale) {
    char *m_str = mpz_get_str(NULL, 10, mantissa);
    if (scale <= 0) {
        if (scale == 0) return m_str;
        size_t abs_s = -scale;
        size_t len = strlen(m_str);
        char *res = malloc(len + abs_s + 1);
        strcpy(res, m_str);
        for(size_t i = 0; i < abs_s; i++) strcat(res, "0");
        free(m_str);
        return res;
    }

    int is_neg = (m_str[0] == '-');
    char *digits = is_neg ? m_str + 1 : m_str;
    size_t d_len = strlen(digits);

    size_t int_part_len = (d_len > (size_t)scale) ? (d_len - scale) : 0;
    size_t frac_part_len = scale;

    char *res = malloc((is_neg ? 1 : 0) + int_part_len + 1 + frac_part_len + 1);
    char *p = res;
    if (is_neg) *p++ = '-';

    if (int_part_len > 0) {
        strncpy(p, digits, int_part_len);
        p += int_part_len;
    } else {
        *p++ = '0';
    }
    *p++ = '.';
    
    if (d_len < (size_t)scale) {
        size_t zeros = scale - d_len;
        for (size_t i = 0; i < zeros; i++) *p++ = '0';
        strcpy(p, digits);
    } else {
        strncpy(p, digits + int_part_len, frac_part_len);
        p += frac_part_len;
        *p = '\0';
    }
    free(m_str);
    return res;
}

// Sum: max(p1, p2) precision
static int gmp_dec_add(lua_State *L) {
    const char *s1 = luaL_checkstring(L, 1);
    long p1 = luaL_checkinteger(L, 2);
    const char *s2 = luaL_checkstring(L, 3);
    long p2 = luaL_checkinteger(L, 4);

    mpz_t m1, m2, res_m;
    mpz_init_set_str(m1, s1, 10);
    mpz_init_set_str(m2, s2, 10);
    mpz_init(res_m);

    long res_scale = (p1 > p2) ? p1 : p2;

    if (p1 < res_scale) mpz_mul_10_pow(m1, m1, res_scale - p1);
    if (p2 < res_scale) mpz_mul_10_pow(m2, m2, res_scale - p2);

    mpz_add(res_m, m1, m2);

    char *out = format_decimal_exact(res_m, res_scale);
    lua_pushstring(L, out);
    free(out);
    mpz_clears(m1, m2, res_m, NULL);
    return 1;
}

// Sub: max(p1, p2) precision
static int gmp_dec_sub(lua_State *L) {
    const char *s1 = luaL_checkstring(L, 1);
    long p1 = luaL_checkinteger(L, 2);
    const char *s2 = luaL_checkstring(L, 3);
    long p2 = luaL_checkinteger(L, 4);

    mpz_t m1, m2, res_m;
    mpz_init_set_str(m1, s1, 10);
    mpz_init_set_str(m2, s2, 10);
    mpz_init(res_m);

    long res_scale = (p1 > p2) ? p1 : p2;

    if (p1 < res_scale) mpz_mul_10_pow(m1, m1, res_scale - p1);
    if (p2 < res_scale) mpz_mul_10_pow(m2, m2, res_scale - p2);

    mpz_sub(res_m, m1, m2);

    char *out = format_decimal_exact(res_m, res_scale);
    lua_pushstring(L, out);
    free(out);
    mpz_clears(m1, m2, res_m, NULL);
    return 1;
}

// Mult: p1 + p2 precision
static int gmp_dec_mul(lua_State *L) {
    const char *s1 = luaL_checkstring(L, 1);
    long p1 = luaL_checkinteger(L, 2);
    const char *s2 = luaL_checkstring(L, 3);
    long p2 = luaL_checkinteger(L, 4);

    mpz_t m1, m2, res_m;
    mpz_init_set_str(m1, s1, 10);
    mpz_init_set_str(m2, s2, 10);
    mpz_init(res_m);

    mpz_mul(res_m, m1, m2);
    long res_scale = p1 + p2;

    char *out = format_decimal_exact(res_m, res_scale);
    lua_pushstring(L, out);
    free(out);
    mpz_clears(m1, m2, res_m, NULL);
    return 1;
}

// Div: Truncation
static int gmp_dec_div(lua_State *L) {
    const char *s1 = luaL_checkstring(L, 1);
    long p1 = luaL_checkinteger(L, 2);
    const char *s2 = luaL_checkstring(L, 3);
    long p2 = luaL_checkinteger(L, 4);
    long target_prec = luaL_checkinteger(L, 5);

    mpz_t m1, m2, res_m;
    mpz_init_set_str(m1, s1, 10);
    mpz_init_set_str(m2, s2, 10);
    mpz_init(res_m);

    long long multiplier = (long long)target_prec + p2 - p1;
    if (multiplier >= 0) {
        mpz_mul_10_pow(m1, m1, (unsigned long)multiplier);
    } else {
        mpz_mul_10_pow(m2, m2, (unsigned long)(-multiplier));
    }

    // Integer division
    mpz_tdiv_q(res_m, m1, m2);

    char *out = format_decimal_exact(res_m, target_prec);
    lua_pushstring(L, out);
    free(out);
    mpz_clears(m1, m2, res_m, NULL);
    return 1;
}

static const struct luaL_Reg gmpdec[] = {
    {"add", gmp_dec_add},
    {"sub", gmp_dec_sub},
    {"mul", gmp_dec_mul},
    {"div", gmp_dec_div},
    {NULL, NULL}
};

int luaopen_gmpdec(lua_State *L) {
    luaL_newlib(L, gmpdec);
    return 1;
}
