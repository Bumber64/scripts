gui/find-hf
===========

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
Local       Tile coordinates, available when not fast traveling.
Travel      The smallest step when traveling the world, equivalent to 16 tiles.
Region      World map tiles, corresponding to world width and height.
            Equivalent to 48 travel tiles or 768 local tiles.
==========  ==========

Usage
-----

::

    gui/find-hf
