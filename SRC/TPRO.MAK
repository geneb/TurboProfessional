
#
#                            TPRO.MAK 5.22
#             Make file used to build Turbo Professional 5.22
#
# This make file is designed to be used only with Borland's MAKE utility; it
# does NOT work with Microsoft's MAKE. To use this file, enter
#
#     MAKE -fTPRO.MAK
#
# at the DOS command line.
#
# TPRO.MAK is designed to work with Turbo Pascal 4.0-7.0 or Borland Pascal
# 7.0, and either Turbo Assembler 1.0+ or the Microsoft Assembler 4.0+. This
# is made possible by MAKE conditional defines. There are several macros that
# must either be defined or commented out, depending on what version of the
# compiler you have and what assembler, if any. See the comments below for
# further instructions.

# ---------------------------------------------------- Macros

# You may need to modify the definitions below in order for MAKE to be able to
# find your compiler and assembler. To comment out a macro, insert '#' at
# the beginning of the line, as is being done here.

# Comment out all but one of the following lines depending on which version
# of Turbo Pascal (4.0-7.0) or Borland Pascal (7.0) you are using:
# tp4=1
# tp5=1
# tp55=1
# tp6=1
# tp7=1
bp7=1

# Activate this line for Borland Pascal 7.0 pmode,
# or comment it out for real mode.
# pmode=1

# Activate this line for Turbo Assembler,
# or comment it out for Microsoft Assembler.
tasm=1

# Comment this line out if you do not have an assembler.
HaveAssembler=1

!if $d(tasm)
assemble=TASM.EXE
!else
assemble=MASM.EXE
!endif

# You may wish to modify the pathnames or command line options in the
# following. For example, you might want to add '/$N+ /$E+' to activate
# floating point emulation, or '/Dusebcd' to activate support for BCD reals
# in TPENTRY.
!if $d(tp4)
compile=TPC.EXE /M /$D-      /$L-
!endif
!if $d(tp5) || $d(tp55) || $d(tp6) || $d(tp7)
compile=TPC.EXE /M /$D- /$L- /L
!endif
!if $d(bp7)
!if $d(pmode)
compile=BPC.EXE /CP /M /$D- /$L-
!else
compile=BPC.EXE /CD /M /$D- /$L-
!endif
!endif

# --------------------------------------- Other factors that affect compilation
#
# Several of the demo programs and units in Turbo Professional depend on
# the state of certain conditional compilation directives that you might wish
# to change. There are also a couple of units that are compiled differently
# depending on whether or not the compiler directives $N+ and/or $E+ are in
# effect. A complete list of these appears below. In each case, the compiler
# directive in question appears on the left, followed by a brief explanation
# of what difference it makes. The default state of the directive is shown in
# parentheses. Note that all the conditional compilation directives that
# affect units are gathered together in TPDEFINE.INC. Those that pertain only
# to a demo program, such as UseEnhKbd in SMACS, are found in the main source
# file for the program.
#
# TP8087
#   $N+, $E+          If these compiler options are on, TP8087 supports Turbo
#                     Pascal's floating point emulator. (NOT SET)
# TPDATE
#   FourByteDates     If defined, dates are stored as longints, giving a range
#                     of 01/01/1600-12/31/3999. If not, dates are stored as
#                     words, giving a range of 01/01/1900-12/31/2078. (DEFINED)
# TPDIR
#   AllowDateTime     If defined, TPDIR can display file sizes, dates and times.
#                     Undefined this can save up to 3200 bytes of code space.
#                     (DEFINED)
# TPEDIT, TPHELP,
# TPPICK, TPENTRY,
# TPMEMO, TPMENU,
# ENTRY, MAKEMENU,
# MEMO, PTRPT,
# VBROWSE, PREF
#   UseMouse          If defined, these units and programs support the mouse
#                     in various ways. See volume 1 of the manual for details.
#                     (DEFINED)
# TPENTRY
#   IncludeNumeric    Enables use of the numeric (right-left) editor. Leaving
#                     this out can save several K of code space. (DEFINED)
#   IncludeChoice     Enables use of multiple choice fields. Leaving
#                     this out can save several K of code space. (DEFINED)
#   UseBCD            Enables support for BCD reals as implemented in TPBCD.
#                     Leaving this out can save several K of code space.
#                     (NOT DEFINED)
#   TpEntryScrolls    Enables scrollable entry screens.
#   $N+               Enables support for 8087 reals. Leaving this out can
#                     save several K of code space. (NOT SET)
# TPMENU, MAKEMENU
#   Tpro5Menu         This define controls whether items within a menu system
#                     can be temporarily disabled and re-enabled. Defining
#                     Tpro5Menu will break (in a small way) menu systems created
#                     with Turbo Professional 4.0. (DEFINED)
# TPPICK
#   PickItemDisable   Enables support for unpickable items.
#   EnablePickOrientations
#                     Enables support for alternate orientations (horizontal,
#                     vertical, snaking).
# TPSORT
#   FastDispose       Deactivate this define if the caller of TPSORT needs to
#                     perform heap allocation or deallocation while the sort
#                     is in progress, that is, within the user-defined
#                     procedures of the sort. For large sorts with element
#                     size > 4 bytes, FastDispose makes a significant difference
#                     in the speed of heap deallocation when the sort is
#                     finished. (DEFINED)
# TPSTRING, TPEDIT
#   $N+               Changes the definition of Float from Real to Extended,
#                     affecting all routines that take reals as parameters.
#                     This also affects the ReadReal routine in TPEDIT, which
#                     must be compiled with $N+ if TPSTRING is.
#                     (NOT SET)
# TPTSR
#   ThwartSideKick    If defined, TPTSR tries to thwart SideKick during
#                     initialization to allow other TSR's to be loaded after it.
#                     (DEFINED)
# TPWINDOW
#   ExplodingWindows  Deactivate this define if exploding windows are not
#                     desired, in order to save about 2200 bytes of code space.
#                     (DEFINED)
#   ShadowedWindows   Deactivate this define if shadowed windows are not
#                     desired, in order to save up to 2000 bytes of code space.
#                     (DEFINED)
# SMACS
#   UseEnhKbd         If defined, SMACS uses the TPENHKBD unit and supports
#                     the enhanced keyboard. (DEFINED)
#
# On a somewhat related subject, the file TP8087e.ASM *must* be assembled using
# Turbo Assembler, *not* MASM. It is doubtful that you would ever need to
# reassemble it. The file TP8087.ASM can be assembled with either MASM or Turbo
# Assembler. Note, however, that if a version of MASM prior to 5.0 is used,
# you must use the /R command line switch in MASM.

# --------------------------------------- Automatic macros

# Undefine pmode when not appropriate
!if !$d(bp7)
!undef pmode
!endif

# Specify the file extension used for a unit
!if $d(pmode)
uext=TPP
!else
uext=TPU
!endif

# --------------------------------------- Force evaluation of all dependencies

!if $d(pmode)
dummy: bcdtrans.obj tp8087.obj tpasciiz.obj tpbcd.obj tpbm.obj tpcase.obj \
       tpcmisc.obj tpcomp.obj tpcrt.obj tpcrt2.obj tpdisk.obj tpems.obj \
       tpenhkbd.obj tperrhan.obj tpfast.obj tpfast2.obj tpflex.obj tpint.obj \
       tpint24.obj tpmaced.obj tpmacro.obj tpmemo.obj tpmouse.obj tppack.obj \
       tpscreen.obj tpsearch.obj tptab.obj tptsr.obj \
       dpmi.tpp tp8087.tpp tpasciiz.tpp tpbcd.tpp tpcmd.tpp tpcmdlin.tpp \
       tpcrt.tpp tpdate.tpp tpdir.tpp tpdos.tpp tpedit.tpp \
       tpenhkbd.tpp tpentry.tpp tperrhan.tpp \
       tphelp.tpp tpinline.tpp tpint.tpp tpint24.tpp tpmaced.tpp tpmacro.tpp \
       tpmemchk.tpp tpmemo.tpp tpmenu.tpp tpmouse.tpp tppick.tpp \
       tprarray.tpp tpscreen.tpp tpsort.tpp tpstrdev.tpp tpstring.tpp \
       tpvarray.tpp tpwindow.tpp \
       bsort.exe diff.exe entry.exe makehelp.exe makemenu.exe memo.exe \
       ptrpt.exe rep.exe tfind.exe vbrowse.exe winexmpl.exe winwow.exe \
       entry.hlp
!else
dummy: bcdtrans.obj tp8087.obj tpasciiz.obj tpbcd.obj tpbm.obj tpcase.obj \
       tpcmisc.obj tpcomp.obj tpcrt.obj tpcrt2.obj tpdisk.obj tpems.obj \
       tpenhkbd.obj tperrhan.obj tpfast.obj tpfast2.obj tpflex.obj tpint.obj \
       tpint24.obj tpmaced.obj tpmacro.obj tpmemo.obj tpmouse.obj tppack.obj \
       tpscreen.obj tpsearch.obj tptab.obj tptsr.obj \
       dpmi.tpu tp8087.tpu tpasciiz.tpu tpbcd.tpu tpcmd.tpu tpcmdlin.tpu \
       tpcrt.tpu tpdate.tpu tpdir.tpu tpdos.tpu tpearray.tpu tpedit.tpu \
       tpems.tpu tpenhkbd.tpu tpentry.tpu tperrhan.tpu tpextmem.tpu \
       tphelp.tpu tpinline.tpu tpint.tpu tpint24.tpu tpmaced.tpu tpmacro.tpu \
       tpmemchk.tpu tpmemo.tpu tpmenu.tpu tpmouse.tpu tppick.tpu \
       tprarray.tpu tpscreen.tpu tpsort.tpu tpstrdev.tpu tpstring.tpu \
       tptsr.tpu tpvarray.tpu tpwindow.tpu \
       bsort.exe diff.exe entry.exe makehelp.exe makemenu.exe memo.exe \
       pcalc.exe pref.exe ptime.exe ptrpt.exe rep.exe smacs.exe tfind.exe \
       vbrowse.exe winexmpl.exe winwow.exe \
       entry.hlp
!endif

# ---------------------------------------------------- Implicit rules

!if $d(HaveAssembler)
.asm.obj:
  $(assemble) $*;
!endif

.pas.exe:
  $(compile) $*

.pas.tpu:
  $(compile) $*

.pas.tpp:
  $(compile) $*

# ---------------------------------------------------- Assembly Language Source

!if $d(HaveAssembler)

bcdtrans.obj: bcdtrans.asm tpcommon.asm tpbcdlow.asm

pref.obj: pref.asm

tp8087.obj: tp8087.asm tpcommon.asm

!if $d(tasm)
tp8087e.obj: tp8087e.asm tpcommon.asm
!endif

tpasciiz.obj: tpasciiz.asm tpcommon.asm

tpbcd.obj: tpbcd.asm tpcommon.asm tpbcdlow.asm bcdarith.asm bcdcomp.asm \
           bcdconv.asm

tpbm.obj: tpbm.asm tpcommon.asm

tpcase.obj: tpcase.asm tpcommon.asm

tpcmisc.obj: tpcmisc.asm tpcommon.asm

tpcomp.obj: tpcomp.asm tpcommon.asm

tpcrt.obj: tpcrt.asm tpcommon.asm

tpcrt2.obj: tpcrt2.asm tpcommon.asm

tpdisk.obj: tpdisk.asm tpcommon.asm

tpems.obj: tpems.asm tpcommon.asm

tpenhkbd.obj: tpenhkbd.asm tpcommon.asm

tperrhan.obj: tperrhan.asm tpcommon.asm

tpfast.obj: tpfast.asm tpcommon.asm

tpfast2.obj: tpfast2.asm tpcommon.asm

tpflex.obj: tpflex.asm tpcommon.asm

tpint.obj: tpint.asm tpcommon.asm

tpint24.obj: tpint24.asm tpcommon.asm

tpmaced.obj: tpmaced.asm tpcommon.asm

tpmacro.obj: tpmacro.asm tpcommon.asm

tpmemo.obj: tpmemo.asm tpcommon.asm

tpmouse.obj: tpmouse.asm tpcommon.asm

tppack.obj: tppack.asm tpcommon.asm

tpscreen.obj: tpscreen.asm tpcommon.asm

tpsearch.obj: tpsearch.asm tpcommon.asm

tptab.obj: tptab.asm tpcommon.asm

tptsr.obj: tptsr.asm tpcommon.asm

!endif

# ---------------------------------------------------- Library Units

dpmi.$(uext): dpmi.pas

!if $d(tasm)
tp8087.$(uext): tp8087.pas tp8087.obj tp8087e.obj
!else
tp8087.$(uext): tp8087.pas tp8087.obj
!endif

tpasciiz.$(uext): tpasciiz.pas tpstring.$(uext) tpasciiz.obj

tpbcd.$(uext): tpbcd.pas tpbcd.obj bcdtrans.obj

tpcrt.$(uext): tpcrt.pas tpinline.$(uext) tpcrt.obj tpcrt2.obj tpfast.obj \
           tpfast2.obj tpcmisc.obj tppack.obj tpflex.obj dpmi.$(uext)

tpdate.$(uext): tpdate.pas tpinline.$(uext) tpdefine.inc

tpdir.$(uext): tpdir.pas tpinline.$(uext) tpdos.$(uext) tpstring.$(uext) tpcrt.$(uext) \
           tpwindow.$(uext) tpdate.$(uext) tppick.$(uext) tpdefine.inc

tpdos.$(uext): tpdos.pas tpstring.$(uext) tpdisk.obj dpmi.$(uext)

tpearray.$(uext): tpearray.pas tpems.$(uext) tpmemchk.$(uext)

tpedit.$(uext): tpedit.pas tpcrt.$(uext) tpcmd.$(uext) tpstring.$(uext) \
            tpmouse.$(uext) tpdefine.inc

tpems.$(uext): tpems.pas tpems.obj

tpenhkbd.$(uext): tpenhkbd.pas tpenhkbd.obj

tpentry.$(uext): tpentry.pas tpentry.in0 tpentry.in1 tpentry.in2 \
             tpentry.in3 tpinline.$(uext) tpcrt.$(uext) tpcmd.$(uext) tpstring.$(uext) \
             tpbcd.$(uext) tpdate.$(uext) tpmemchk.$(uext) tpmouse.$(uext) tpwindow.$(uext) \
             tpdefine.inc

tperrhan.$(uext): tperrhan.pas tperrhan.obj

tpextmem.$(uext): tpextmem.pas

tphelp.$(uext): tphelp.pas tpdos.$(uext) tpstring.$(uext) tpcrt.$(uext) \
            tpwindow.$(uext) tppick.$(uext) tpcmd.$(uext) tpmemchk.$(uext) tpmouse.$(uext) \
            tpdefine.inc

tpinline.$(uext): tpinline.pas

tpint.$(uext): tpint.pas tpint.obj

tpint24.$(uext): tpint24.pas tpint24.obj

tpmaced.$(uext): tpmaced.pas tpcrt.$(uext) tpint.$(uext) tpmacro.$(uext) tpmaced.obj

tpmacro.$(uext): tpmacro.pas tpint.$(uext) tpmacro.obj

tpmemo.$(uext): tpmemo.pas tpmemo.obj tpdefine.inc \
            tpcrt.$(uext) tpmouse.$(uext) tpcmd.$(uext) tpstring.$(uext)

tpmenu.$(uext): tpmenu.pas tpmenu.in0 tpmenu.in1 tpmenu.in2 tpstring.$(uext) \
            tpcrt.$(uext) tpcmd.$(uext) tpwindow.$(uext) tpmouse.$(uext) tpmemchk.$(uext) \
            tpdefine.inc

tpmouse.$(uext): tpmouse.pas tpcrt.$(uext) tpmouse.obj dpmi.$(uext)

tppick.$(uext): tppick.pas tppick.in1 tpcrt.$(uext) tpstring.$(uext) \
            tpwindow.$(uext) tpcmd.$(uext) tpmouse.$(uext) tpdefine.inc

tprarray.$(uext): tprarray.pas tpmemchk.$(uext)

tpscreen.$(uext): tpscreen.pas tpcrt.$(uext) tpscreen.obj

tpsort.$(uext): tpsort.pas tpdefine.inc

tpstrdev.$(uext): tpstrdev.pas

tpstring.$(uext): tpstring.pas tpcase.obj tpcomp.obj tpsearch.obj \
              tptab.obj tpbm.obj

tptsr.$(uext): tptsr.pas tpint.$(uext) tptsr.obj tpdefine.inc

tpvarray.$(uext): tpvarray.pas tpmemchk.$(uext)

tpwindow.$(uext): tpwindow.pas tpcrt.$(uext) tpmemchk.$(uext)  tpdefine.inc

# ---------------------------------------------------- Other Units

tpcmd.$(uext): tpcmd.pas

tpcmdlin.$(uext): tpcmdlin.pas

tpmemchk.$(uext): tpmemchk.pas

# ---------------------------------------------------- Demo Programs

# best.exe: best.pas tpdefine.inc tpcrt.$(uext) tpstring.$(uext) tpmouse.$(uext) tpentry.$(uext)

bsort.exe: bsort.pas tpstring.$(uext) tpdos.$(uext) tpsort.$(uext)

!if $d(pmode)
diff.exe: diff.pas tpdefine.inc tpstring.$(uext) tpdos.$(uext) tpasciiz.$(uext)
!else
diff.exe: diff.pas tpdefine.inc tpstring.$(uext) tpdos.$(uext) tpasciiz.$(uext) \
          tpextmem.$(uext) tpems.$(uext)
!endif

entry.exe: entry.pas tpstring.$(uext) tpcrt.$(uext) tpdate.$(uext) tpentry.$(uext) \
           tpmemo.$(uext) tpwindow.$(uext) tppick.$(uext) tphelp.$(uext) tpdefine.inc

makemenu.exe: makemenu.pas makemenu.inc tpstring.$(uext) tpcrt.$(uext) tpedit.$(uext) \
              tpcmd.$(uext) tpwindow.$(uext) tpmenu.$(uext) tpmouse.$(uext) tpdefine.inc

memo.exe: memo.pas tpcrt.$(uext) tpstring.$(uext) tpmouse.$(uext) tpmemo.$(uext) tpdefine.inc

pcalc.exe: pcalc.pas tpbcd.$(uext) tpstring.$(uext) tpcrt.$(uext) tpint.$(uext) tptsr.$(uext)

pref.exe: pref.pas pref.obj tpcrt.$(uext) tpint.$(uext) tptsr.$(uext) tpstring.$(uext) \
          tpmouse.$(uext) tpdefine.inc

ptime.exe: ptime.pas tpstring.$(uext) tpcrt.$(uext) tpdate.$(uext) tpedit.$(uext) tpint.$(uext) \
           tptsr.$(uext)

ptrpt.exe: ptrpt.pas tpint24.$(uext) tpstring.$(uext) tpdos.$(uext) tpcrt.$(uext) tpdate.$(uext) \
           tpentry.$(uext) tpedit.$(uext) tppick.$(uext) tpdir.$(uext) tpmenu.$(uext) tpdefine.inc

rep.exe: rep.pas tpstring.$(uext) tpcmdlin.$(uext) tpdos.$(uext) tpint.$(uext) tpmacro.$(uext)

smacs.exe: smacs.pas smacs.inc tpenhkbd.$(uext) tpint24.$(uext) \
           tpstring.$(uext) tpdos.$(uext) tpcrt.$(uext) tpedit.$(uext) tpint.$(uext) tptsr.$(uext) \
           tpmacro.$(uext) tpmaced.$(uext)

tfind.exe: tfind.pas tpstring.$(uext) tpcmdlin.$(uext) tpdos.$(uext) tpasciiz.$(uext)

vbrowse.exe: vbrowse.pas tpstring.$(uext) tpdos.$(uext) tpcrt.$(uext) tpedit.$(uext) \
             tpwindow.$(uext) tpvarray.$(uext) tpdefine.inc

winexmpl.exe: winexmpl.pas tpcrt.$(uext) tpscreen.$(uext)

winwow.exe: winwow.pas tpstring.$(uext) tpcrt.$(uext) tpwindow.$(uext)

# ---------------------------------------------------- Utility Programs

makehelp.exe: makehelp.pas tpdos.$(uext) tpstring.$(uext) tpcrt.$(uext) tpwindow.$(uext) \
              tppick.$(uext) tphelp.$(uext) tpmemchk.$(uext)

# ---------------------------------------------------- Other Stuff

# Build help file for ENTRY

entry.hlp: entry.txt makehelp.exe
  makehelp -q entry.txt
