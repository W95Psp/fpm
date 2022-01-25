let kinds = [ 'UseInterface', 'PreferInterface',
	      'UseImplementation', 'FriendImplementation' ];

let parse_decl = s => {
    let chunks = s.match(/^\s*([^\s]+)\s*->\s*\[([^\]]*)\]\s*/);
    if (!chunks)
	throw `Expected a decl (i.e. 'name -> [d0; d1; d2]') got '${s}' instead`;
    let [_, path, deps] = chunks;
    deps = deps.split(';').map(x => x.trim()).filter(x => x).map(x => {
	let y = x.split(/\s+/).map(x => x.trim());
	if(y.length != 2)
	    throw `Expected e.g. 'UseInterface name', got '${x}'`;
	let [kind, module] = y;
	if(!kinds.includes(kind))
	    throw `Expected the kind to be in the list [${kinds.join(', ')}], got '${kind}' instead.`;
	return {kind, module};
    });
    return {path, deps};
};

let list = require('fs').readFileSync(0, 'utf-8').split(';;')
    .map(x => x.trim())
    .filter(x => x)
    .map(parse_decl);

let dict = {
    graph: {},
    pathsOfModName: {}
};
for(let {path, deps} of list) {
    dict.graph[path] = deps;
    let basename = require('path').basename(path);
    console.log(basename);
    let modulename = basename.match(/^(.*).fsti?$/)[1].toLowerCase();
    dict.pathsOfModName[modulename] = dict.pathsOfModName[modulename] || [];
    dict.pathsOfModName[modulename].push(path);
}




console.log(JSON.stringify(dict, null, 4));

