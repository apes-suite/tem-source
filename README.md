TreElM
======

The Tree-based Elemental Mesh library provides the functionality to act on a
distributed parallel octree mesh.
More detailed
[Documentation](https://geb.inf.tu-dresden.de/doxy/treelm/index.html) is
generated by [FORD](https://github.com/cmacmackin/ford).

TreElM is licensed under the simplified
[BSD license](http://www.opensource.org/licenses/BSD-2-Clause).
Please have a look in the included COPYRIGHT file for more details.

In the build script, the Fortran preprocessing tool CoCo is included, which is
released under the [GPL](http://www.opensource.org/licenses/gpl-2.0.php) version 2.
The CoCo source is also available in external/coco.f90.

TreElM is part of the [APES suite](https://apes.osdn.io/).


How To Build
------------

[waf](https://waf.io/) is used as a build system.
Run:

~~~~~~~~~~~~~~~~~~~~~{.sh}
./waf configure build
~~~~~~~~~~~~~~~~~~~~~

to build the treelm library.
If you want to select a specific Fortran compiler, set the environment variable
*FC* accordingly. Note, that this compiler has to support MPI, therefore usually
*FC* should point to a MPI wrapper provided by the MPI library.
To adapt the build further have a look at the wscript.

For your convenience, the [aotus](https://apes.osdn.io/pages/aotus) library is
included and built along.
It is used for the header description files of the mesh as well as for
configuration options.
