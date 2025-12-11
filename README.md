# TurboPower Turbo Professional v5.22

22 years ago, TurboPower Software closed their doors as a retail software company and released all of their development libraries the for Borland[1]/CodeGear/Embarcadero Delphi compiler.  These items were released under a Mozilla 1.1 license.

Here's their original announcement: http://www.turbopower.com/

Unfortunately, nobody seems to have been able to get their attention about making their fantastic MS-DOS libraries for Turbo Pascal available online.

Their website clearly states, "TurboPower libraries released as open source".  Their MS-DOS libraries would appear to fall under that statement.  Maybe they figured, "Hey, it's 2003. Nobody's going to be interested in this ancient DOS stuff!"

Well dammit, **I'm** interested!  I'm sure I'm not the only one.

The original product description for Turbo Professional can be found [here](https://web.archive.org/web/20000919042449/http://www.turbopower.com/products/tpro/).

I spent a great deal of time chasing down the most recent version of Turbo Professional that I could find and then applied all the patches that I could find.  That work resulted in this repository.

Most recently, I found and updated the TpCrt units with versions that would not crash on fast machines.  More information on that can be found in DOC\TPCRTFIX.TXT.

As far as I can determine, v5.22 was the last version of Turbo Professional that was released.


## Building

Turbo Professional can be built using Turbo Pascal versions 4.0 to 7.0, and Borland Pascal v7.0.  In the case of Borland Pascal 7.0, units can be built for both real mode (TPU) and protected mode (TPP).  The build process also requires Turbo Assembler v1.0 or greater, or Microsoft Assembler v4.0 or greater in order to assemble the .ASM files.  You'll need to ensure that your build tools are in your DOS path.

The file SRC\TPDEFINE.INC has settings that can be changed in order to affect how Turbo Professional is built and functions.  It would be worth your time to peruse that file - note that unless you know **why** you're going to change something, you probably should leave it the default.

The Makefile for Turbo Professional can be found in SRC\TPRO.MAK.  This file will allow you to adjust a number of different things about how the units are built.  I recommend going through it - the settings it uses are very well documented.  Note that the Makefile uses the Borland Make syntax.

Change to the SRC directory and kick off the build with `MAKE -FTPRO`.  This will build all the units, all the object files, compile the help files, and build all the examples.  Copy all the TPU and/or TPP unit files to some location that you can easily point the compiler's Unit Directory setting at.  You're done!

## Documentation

Unfortunately, right now there isn't any.  I've been searching for years for copies of the Turbo Professional manuals, and I've come up with nothing.  If you or someone you know have those manuals and would be willing to loan them out, I would be happy to non-destructively scan them and return them at my expense. 

Hopefully more people than just me will find this repository useful.




