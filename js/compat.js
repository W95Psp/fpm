var global = Function('return this')();

global.caml_thread_initialize = (...args) => {};
global.caml_mutex_new  = (...args) => {};

let gg = (n, f) => {
    global[n] = (...args) => {if(!f)	throw n; else return f(...args);};
};

gg("int128_init_custom_ops ", _ => null);
gg("int128_max_int         ", x => Math.pow(2,64));
gg("int128_min_int         ", x => -Math.pow(2,64));
gg("int128_of_int          ", n => n);
gg("int40_max_int          ", x => Math.pow(2,64));
gg("int40_min_int          ", x => -Math.pow(2,64));
gg("int40_of_int           ", n => n);
gg("int48_max_int          ", x => Math.pow(2,64));
gg("int48_min_int          ", x => -Math.pow(2,64));
gg("int48_of_int           ", n => n);
gg("int56_max_int          ", x => Math.pow(2,64));
gg("int56_min_int          ", x =>-Math.pow(2,64));
gg("int56_of_int           ", n => n);
gg("uint128_init_custom_ops", _ => null);
gg("uint128_max_int        ", x => Math.pow(2,64));
gg("uint128_of_int         ", x => x);
gg("uint32_init_custom_ops ", x => null);
gg("uint32_max_int         ", x => Math.pow(2,64));
gg("uint32_of_int          ", x => x);
gg("uint32_sub             ", (x,y) => x-y);
gg("uint40_of_int          ", x => x);
gg("uint48_of_int          ", x => x);
gg("uint56_of_int          ", x => x);
gg("uint64_init_custom_ops ", x => null);
gg("uint64_max_int         ", x => Math.pow(2,64));
gg("uint64_of_int          ", x => x);
gg("uint64_sub             ", (x,y) => x - y);

