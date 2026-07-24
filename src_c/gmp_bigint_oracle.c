#include <lua.h>
#include <lauxlib.h>
#include <gmp.h>
#include <stdlib.h>

// General operation template
static int do_gmp_op(lua_State *L, void (*gmp_func)(mpz_t, const mpz_t, const mpz_t)) {
    const char *s1 = luaL_checkstring(L, 1);
    const char *s2 = luaL_checkstring(L, 2);
    
    mpz_t a, b, res;
    mpz_init_set_str(a, s1, 10);
    mpz_init_set_str(b, s2, 10);
    mpz_init(res);
    
    gmp_func(res, a, b);
    
    char *out_str = mpz_get_str(NULL, 10, res);
    lua_pushstring(L, out_str);
    
    free(out_str);
    mpz_clears(a, b, res, NULL);
    return 1;
}

// Operator functions
static int gmp_add(lua_State *L) { return do_gmp_op(L, mpz_add); }
static int gmp_sub(lua_State *L) { return do_gmp_op(L, mpz_sub); }
static int gmp_mul(lua_State *L) { return do_gmp_op(L, mpz_mul); }
static int gmp_div(lua_State *L) { return do_gmp_op(L, mpz_tdiv_q); } // Integer division
static int gmp_mod(lua_State *L) { return do_gmp_op(L, mpz_tdiv_r); }

static int gmp_pow(lua_State *L) {
    const char *s1 = luaL_checkstring(L, 1);
    unsigned long exp = (unsigned long)luaL_checkinteger(L, 2); // Power as int
    
    mpz_t base, res;
    mpz_init_set_str(base, s1, 10);
    mpz_init(res);
    
    mpz_pow_ui(res, base, exp);
    
    char *out_str = mpz_get_str(NULL, 10, res);
    lua_pushstring(L, out_str);
    
    free(out_str);
    mpz_clears(base, res, NULL);
    return 1;
}

// Modules
static const struct luaL_Reg gmporacle[] = {
    {"add", gmp_add},
    {"sub", gmp_sub},
    {"mul", gmp_mul},
    {"div", gmp_div},
    {"mod", gmp_mod},
    {"pow", gmp_pow},
    {NULL, NULL}
};

int luaopen_gmporacle(lua_State *L) {
    luaL_newlib(L, gmporacle);
    return 1;
}
