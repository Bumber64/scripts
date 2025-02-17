gui/adv-finder
==============

.. dfhack-tool::
    :summary: Find and track historical figures
    :tags: adventure armok inspection units

Allows you to search for all :wiki:`Historical Figures <Historical_figure>` in
the current world. Your coordinates, as well as the selected historical
figure's, are kept up to date as you or your target move. Note that it might
be impossible to find dead historical figures or those that are not in the
physical realm. There are three types of coordinates, and the relevant ones
will be displayed depending on the situation:

==========  ==========
Coord Type  Meaning
==========  ==========
Local       Tile coordinates, available when not fast traveling or sleeping.
            Your target's local coordinates are displayed when nearby.
Travel      The smallest step when traveling the world, equivalent to 16 tiles.
Region      World map tiles, corresponding to world width and height.
            Equivalent to 48 travel tiles or 768 local tiles.
==========  ==========

For Travel and Region coordinates, the Z component will only be displayed if it
can be determined. This represents an underground layer depth, so the surface
is represented by ``Z0`` and the first cavern layer is ``Z-1``.

A compass and relative coordinates will also be displayed. The relative
coordinate display uses the most precise ones shared between you and your target.

Usage
-----

::

    gui/adv-finder
