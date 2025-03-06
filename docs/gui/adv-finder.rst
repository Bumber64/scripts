gui/adv-finder
==============

.. dfhack-tool::
    :summary: Find and track historical figures and artifacts
    :tags: adventure armok inspection items units

A real-time tracker for historical figures and artifacts. Select a target by
clicking the settings icon [☼] and selecting an entry from the lists in
their respective tabs. The lists can be filtered by search string, as well as
by excluding dead figures. Artifacts can exclude books, and the "dead" filter
excludes artifacts held by dead figures (which are generally unrecoverable).
Your coordinates will be kept up to date alongside your target's. There are
two types of coordinates, and they will be displayed as they can be determined.

==========  ==========
Coord Type  Meaning
==========  ==========
Global      Distance in map blocks from the world origin (northwest corner).
            Adventurer usually moves by 3 blocks during fast travel, but slows
            to 1 when the zoomed site map is displayed. Equivalent to 16 local
            tiles. Always available except for targets with an indeterminate
            location.
Local       Tile coordinates, available outside of fast travel and sleeping.
            Your target's local coordinates are displayed when nearby and
            loaded. Local coordinates will remain consistent within a site, but
            will jump around in the wilderness as areas of the world are loaded.
==========  ==========

For global coordinates, the Z component will only be displayed if it can be
specifically determined by the location type. This represents an underground
layer depth, so the surface is indicated by ``Z0`` and the first cavern layer
is ``Z-1``.

A compass and relative coordinates will be displayed. The relative coordinate
display uses the most precise coordinate type shared between you and your
target.

Usage
-----

::

    gui/adv-finder
