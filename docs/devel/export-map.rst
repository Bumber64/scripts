export-map
==========

.. dfhack-tool::
    :summary: Export fortress map tile data to a JSON file.
    :tags: dev

WARNING - This command will cause the game to freeze for minutes depending on
map size and options enabled.

Exports the fortress map tile data to a JSON file. The export does not include items,
characters, buildings, etc. Depending on options enabled, there will be a
``KEY`` table in the JSON with relevant [number ID] values that match a number
to their object type.

Usage
-----

::

    export-map
    export-map (include|exclude) <options>

Examples
--------

``export-map``
    Export the fortress map to JSON with ALL data included.

``export-map include -m -s -v``
    Export the fortress map to JSON with only materials, shape, and variant
    data included.

``export-map exclude --variant --hidden --light``
    Export the fortress map to JSON with variant, hidden, and light data
    excluded.

Required
--------

When you are using options, you must include one of these settings.

``include``
    Include only the data listed from options to the JSON (whitelist).

``exclude``
    Exclude only the data listed from options to the JSON (blacklist).

Options
-------

``help``, ``--help``
    Shows the help menu

``-t``, ``--tiletype``
    The tile material classification. [number ID] (AIR/SOIL/STONE/RIVER/etc.)

``-s``, ``--shape``
    The tile shape classification. [number ID] (EMPTY/FLOOR/WALL/STAIR/etc.)

``-p``, ``--special``
    The tile surface special properties for smoothness. [number ID]
    (NORMAL/SMOOTH/ROUGH/etc.) (used for engraving).

``-v``, ``--variant``
    The specific variant of a tile that have visual variations. [number] (like
    grass tiles in ASCII mode)

``-h``, ``--hidden``
    Whether tile is revealed or unrevealed. [boolean]

``-l``, ``--light``
    Whether tile is exposed to light. [boolean]

``-b``, ``--subterranean``
    Whether the tile is considered underground. [boolean] (used to determine
    crops that can be planted underground)

``-o``, ``--outside``
    Whether the tile is considered “outside”. [boolean] (used by weather effects
    to trigger on outside tiles)

``-a``, ``--aquifer``
    Whether the tile is considered an aquifer. [number ID] (NONE/LIGHT/HEAVY)

``-m``, ``--material``
    The material inside the tile. [number ID] (IRON/GRANITE/CLAY/
    TOPAZOLITE/BLACK_OPAL/etc.) (will return nil if the tile is empty)

``-u``, ``--underworld``
    Whether the underworld z-levels will be included.

``-e``, ``--evilness``
    Whether the evilness value will be included in MAP_SIZE table. This only
    checks the value of the center map tile at ground level and will ignore
    biomes at the edges of the map.

JSON DATA
---------

``ARGUMENT_OPTION_ORDER``
    The order of the selected options for how data is arranged at a map 
    position.

    Example 1:
        ``{"material": 1, "shape": 2, "hidden": 3}``

        ``map[z][y][x] = {material_data, shape_data, hidden_data}``

    Example 2:
        ``{"variant": 3, "light": 1, "outside": 2, "aquifer": 4}``

        ``map[z][y][x] = {light_data, outside_data, variant_data, aquifer_data}``

``MAP_SIZE``
    A table containing basic information about the map size for width, height,
    depth. (x, y, z) The underworld_z_level is included if the underworld option
    is enabled and the map depth (z) will be automatically adjusted.

``KEYS``
    The tables containing the [number ID] values for different options.

    ``"SHAPE": {"-1": "NONE", "0": "EMPTY", "1": "FLOOR", "2": "BOULDERS",
    "3": "PEBBLES", "4": "WALL", ..., "18": "ENDLESS_PIT"}``

    ``"PLANT": {"0": "SINGLE-GRAIN_WHEAT", "1": "TWO-GRAIN_WHEAT",
    "2": "SOFT_WHEAT", "3": "HARD_WHEAT", "4": "SPELT", "5": "BARLEY", ...,
    "224": "PALM"}``

    ``"AQUIFER": {"0": "NONE", "1": "LIGHT", "2": "HEAVY"}``

    Note - when using the ``materials`` option, you need to pair the [number ID]
    with the correct ``KEYS`` material table. Generally you use ``tiletype``
    option as a helper to sort tiles into different material types. I would
    recommend consulting ``tile-material.lua`` to see how materials are sorted.

``map``
    JSON map data is arranged as: ``map[z][y][x] = {tile_data}``

    JSON maps start at index [1]. (starts at map[1][1][1])
    DF maps start at index [0]. (starts at map[0][0][0])

    To translate an actual DF map position from the JSON map you need add +1 to
    all x/y/z coordinates to get the correct tile position.

    The ``ARGUMENT_OPTION_ORDER`` determines order of tile data. (see above)
    I would recommend referencing the tile data like so:

    ``shape = json_data.map[z][x][y][json_data.ARGUMENT_OPTIONS_ORDER.shape]``

    ``light = json_data.map[z][x][y][json_data.ARGUMENT_OPTIONS_ORDER.light]``

    Note - some of the bottom z-levels for hell do not have the same
    width/height as the default map. So if your map is 190x190, the last hell
    z-levels are gonna be like 90x90.

    Instead of returning normal tile data like:

    ``map[0][90][90] = {tile_data}``

    It will return nil instead:

    ``map[0][91][91] = nil``

    So you need to account for this!
