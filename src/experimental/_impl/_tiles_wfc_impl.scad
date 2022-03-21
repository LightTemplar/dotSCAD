use <util/rand.scad>;
use <util/some.scad>;
use <util/sum.scad>;
use <util/map/hashmap.scad>;
use <util/map/hashmap_put.scad>;
use <util/map/hashmap_get.scad>;
use <util/map/hashmap_keys.scad>;
use <util/map/hashmap_entries.scad>;
use <util/set/hashset.scad>;
use <util/set/hashset_elems.scad>;

function weights_of_tiles(sample) = 
    let(
	    symbols = [for(row = sample) each row],
		leng = len(symbols)
	)
    hashmap_entries(_weights_of_tiles(hashmap(number_of_buckets = leng), symbols, leng));

function _weights_of_tiles(weights, symbols, leng, i = 0) =
    i == leng ? weights :
	    let(
		    tile = symbols[i],
			w = hashmap_get(weights, tile)
	    )
		_weights_of_tiles(hashmap_put(weights, tile, w == undef ? 1 : w + 1), symbols, leng, i + 1);

/* 
    oo-style

    wave_function(width, height, weights)
	    - wf_width(wf)
        - wf_height(wf)
        - wf_weights(wf)
		- wf_eigenstates(wf)
		- wf_eigenstates_at(wf, x, y)
		- wf_collapse(wf, x, y, weights)
		- wf_entropy_weights(wf, x, y)
		- wf_coord_weights_min_entropy(wf, notCollaspedCoords)
		- wf_not_collapsed_coords(wf, notCollaspedCoords)
*/
function wave_function(width, height, weights) = 
    [width, height, weights, _initialEigenstates(width, height, weights)];	

function _initialEigenstates(width, height, weights) =
	let(
	    keys = [for(weight = weights) weight[0]], 
        row = [for(x = [0:width - 1]) keys]
	)	
	[for(y = [0:height - 1]) row];

function wf_width(wf) = wf[0];
function wf_height(wf) = wf[1];
function wf_weights(wf) = wf[2];
function wf_eigenstates(wf) = wf[3];
function wf_eigenstates_at(wf, x, y) = wf_eigenstates(wf)[y][x];

function get_state_weight(weights, state) = weights[search([state], weights)[0]][1];

function wf_collapse(wf, x, y, weights) =
    let(
		states = wf_eigenstates_at(wf, x, y),
		wets = is_undef(weights) ? 
		    let(all_weights = wf_weights(wf)) [for(state = states) get_state_weight(all_weights, state)] : 
			weights,
		threshold = rand() * sum(wets)
	)		
	_wf_collapse(wf, x, y, states, wets, len(states), threshold);

function _wf_collapse(wf, x, y, states, weights, leng, threshold, i = 0) =
    threshold < 0 || i == leng ? wf : 
	_wf_collapse(
		threshold < weights[i] ? _replaceStatesAt(wf, x, y, [states[i]]) : wf, 
		x, y, states, weights, leng, threshold - weights[i], i + 1
	);

// Shannon entropy
function wf_entropy_weights(wf, x, y) = 
    let(
		all_weights = wf_weights(wf),
		weights = [for(state = wf_eigenstates_at(wf, x, y)) get_state_weight(all_weights, state)],
		sumOfWeights = sum(weights),
		sumOfWeightLogWeights = sum([for(w = weights) w * ln(w)]) 
	)
	[ln(sumOfWeights) - (sumOfWeightLogWeights / sumOfWeights) - rand() / 1000, weights];

function _replaceStatesAt(wf, x, y, states) = 
    let(
	    eigenstates = wf_eigenstates(wf),
		rowY = eigenstates[y],
		leng_rowY = len(rowY),	
		leng_eigenstates = len(eigenstates),
		newRowY = [for(i = 0; i < leng_rowY; i = i + 1) i == x ? states : rowY[i]]	
	)
	[
	    wf_width(wf),
		wf_height(wf),
		wf_weights(wf),
		[for(i = 0; i < leng_eigenstates; i = i + 1) i == y ? newRowY : eigenstates[i]]
	];

function wf_not_collapsed_coords(wf, notCollaspedCoords) = 
    is_undef(notCollaspedCoords) ?
	let(rx = [0:wf_width(wf) - 1])
	[
		for(y = [0:wf_height(wf) - 1], x = rx)
		if(len(wf_eigenstates_at(wf, x, y)) != 1) [x, y]
	] :
	[
		for(coord = notCollaspedCoords)
		if(len(wf_eigenstates_at(wf, coord.x, coord.y)) != 1) coord
	];

function wf_coord_weights_min_entropy(wf, notCollaspedCoords) = 
    let(
		coord_entropy_weights_lt = [
			for(coord = notCollaspedCoords)
			let(x = coord.x, y = coord.y)
			[x, y, wf_entropy_weights(wf, x, y)] 
		],
		m = coord_entropy_weights_lt[0],
		min_coord_entropy_weights = _coord_entropy_weights(coord_entropy_weights_lt, len(coord_entropy_weights_lt), m)
	)
    [min_coord_entropy_weights.x, min_coord_entropy_weights.y, min_coord_entropy_weights[2][1]];

function _coord_entropy_weights(coord_entropy_weights_lt, leng, m, i = 1) = 
    i == leng ? m :
	let(cm = coord_entropy_weights_lt[i])
	_coord_entropy_weights(coord_entropy_weights_lt, leng, m[2][0] <= cm[2][0] ? m : cm, i + 1);
	
/*
	- tilemap(width, height, sample)
		- tilemap_width(tm)
		- tilemap_height(tm)
		- tilemap_compatibilities(tm)
		- tilemap_wf(tm)
*/

function tilemap(width, height, sample) = [
	width, 
	height, 
	compatibilities_of_tiles(sample), 
	wave_function(width, height, weights_of_tiles(sample))
];

function tilemap_width(tm) = tm[0];
function tilemap_height(tm) = tm[1];
function tilemap_compatibilities(tm) = tm[2];
function tilemap_wf(tm) = tm[3];

function propagate(w, h, compatibilities, wf, x, y) = 
	_propagate(
		w, 
		h,
		compatibilities,
		wf,
		create_stack([x, y])
	);

function _propagate(w, h, compatibilities, wf, stack) =
    stack == [] ? wf :
	let(
		current_coord = stack[0],
		cs = stack[1],
		cx = current_coord.x, 
		cy = current_coord.y,
		current_tiles = wf_eigenstates_at(wf, cx, cy),
		dirs = neighbor_dirs(cx, cy, w, h),
		wf_stack = _doDirs(compatibilities, wf, cs, cx, cy, current_tiles, dirs, len(dirs))
	)
    _propagate(w, h, compatibilities, wf_stack[0], wf_stack[1]);

function _doDirs(compatibilities, wf, stack, cx, cy, current_tiles, dirs, leng, i = 0) = 
    i == leng ? [wf, stack] :
	let(
		dir = dirs[i],
		nbrx = cx + dir[0],
		nbry = cy + dir[1],
		nbr_tiles = wf_eigenstates_at(wf, nbrx, nbry),
		compatible_nbr_tiles = [
			for(nbr_tile = nbr_tiles) 
			if(compatible_nbr_tile(compatibilities, current_tiles, nbr_tile, dir)) nbr_tile
		],
		leng_compatible_nbr_tiles = len(compatible_nbr_tiles),

		wf_stack =
			assert(leng_compatible_nbr_tiles > 0,
					str("(", nbrx, ", ", nbry, ")", 
					" reaches a contradiction. Tiles have all been ruled out by your previous choices. Please try again."))

			leng_compatible_nbr_tiles == len(nbr_tiles) ? 
				[wf, stack] 
				: 
				[   
					_replaceStatesAt(wf, nbrx, nbry, compatible_nbr_tiles), 
					stack_push(stack, [nbrx, nbry])
				]
	)
	_doDirs(compatibilities, wf_stack[0], wf_stack[1], cx, cy, current_tiles, dirs, leng, i + 1);

function generate(w, h, compatibilities, wf, notCollaspedCoords) =
	len(notCollaspedCoords) == 0 ? collapsed_tiles(wf) :
	let(
		coord_weights = wf_coord_weights_min_entropy(wf, notCollaspedCoords),
		x = coord_weights.x,
		y = coord_weights.y,
		weights = coord_weights[2],
		nwf = propagate(w, h, compatibilities, wf_collapse(wf, x, y, weights), x, y)
	)
	generate(w, h, compatibilities, nwf, wf_not_collapsed_coords(nwf));

function neighbor_dirs(x, y, width, height) = [
	if(x > 0)          [-1,  0],   // left
	if(x < width - 1)  [ 1,  0],   // right 
	if(y > 0)          [ 0, -1],   // top
	if(y < height - 1) [ 0,  1]    // bottom
];

function neighbor_compatibilities(sample, x, y, width, height) = 
    let(me = sample[y][x])
	[for(dir = neighbor_dirs(x, y, width, height)) [me, sample[y + dir[1]][x + dir[0]], dir]];

function compatibilities_of_tiles(sample) =
    let(
		width = len(sample[0]), 
		height = len(sample),
		rx = [0:width - 1]
	)
	hashset_elems(hashset([
		for(y = [0:height - 1], x = rx)
		each neighbor_compatibilities(sample, x, y, width, height)
	], number_of_buckets = width * height));

function collapsed_tiles(wf) =
    let(
		wf_h = wf_height(wf),
		wf_w = wf_width(wf),
		rx = [0:wf_w - 1]
	)
	[
		for(y = [0:wf_h - 1])
		[for(x = rx) wf_eigenstates_at(wf, x, y)[0]]
	];

function compatible_nbr_tile(compatibilities, current_tiles, nbr_tile, dir) =
    some(current_tiles, function(tile) search([[tile, nbr_tile, dir]], compatibilities) != [[]]);

function create_stack(elem) = [elem, []];
function stack_push(stack, elem) = [elem, stack];
// function stack_pop(stack) = stack;
function stack_len(stack) = 
    is_undef(stack[0]) ? 0 : 1 + stack_len(stack[1]); 