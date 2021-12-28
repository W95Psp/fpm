"use strict";

var global = Function('return this')();

global.caml_thread_initialize = function () {};
global.caml_mutex_new = function () {};

var gg = function gg(n, f) {
    global[n] = function () {
        if (!f) throw n;else return f.apply(undefined, arguments);
    };
};

gg("int128_init_custom_ops ", function (_) {
    return null;
});
gg("int128_max_int         ", function (x) {
    return Math.pow(2, 64);
});
gg("int128_min_int         ", function (x) {
    return -Math.pow(2, 64);
});
gg("int128_of_int          ", function (n) {
    return n;
});
gg("int40_max_int          ", function (x) {
    return Math.pow(2, 64);
});
gg("int40_min_int          ", function (x) {
    return -Math.pow(2, 64);
});
gg("int40_of_int           ", function (n) {
    return n;
});
gg("int48_max_int          ", function (x) {
    return Math.pow(2, 64);
});
gg("int48_min_int          ", function (x) {
    return -Math.pow(2, 64);
});
gg("int48_of_int           ", function (n) {
    return n;
});
gg("int56_max_int          ", function (x) {
    return Math.pow(2, 64);
});
gg("int56_min_int          ", function (x) {
    return -Math.pow(2, 64);
});
gg("int56_of_int           ", function (n) {
    return n;
});
gg("uint128_init_custom_ops", function (_) {
    return null;
});
gg("uint128_max_int        ", function (x) {
    return Math.pow(2, 64);
});
gg("uint128_of_int         ", function (x) {
    return x;
});
gg("uint32_init_custom_ops ", function (x) {
    return null;
});
gg("uint32_max_int         ", function (x) {
    return Math.pow(2, 64);
});
gg("uint32_of_int          ", function (x) {
    return x;
});
gg("uint32_sub             ", function (x, y) {
    return x - y;
});
gg("uint40_of_int          ", function (x) {
    return x;
});
gg("uint48_of_int          ", function (x) {
    return x;
});
gg("uint56_of_int          ", function (x) {
    return x;
});
gg("uint64_init_custom_ops ", function (x) {
    return null;
});
gg("uint64_max_int         ", function (x) {
    return Math.pow(2, 64);
});
gg("uint64_of_int          ", function (x) {
    return x;
});
gg("uint64_sub             ", function (x, y) {
    return x - y;
});
