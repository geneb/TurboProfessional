{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$IFDEF Dpmi}
  !! ERROR - This unit is not compatible with Protected mode !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{$IFNDEF Ver40}
  {$R-,O-,A-}
{$ENDIF}

{*********************************************************}
{*                   TPEMS.PAS 5.22                      *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpEms;
  {-EMS memory management routines}

interface

const
  EmsErrorCode = $0FFFF;     {Used by several functions to signal an error}

function EmsInstalled : Boolean;
  {-Returns true if the EMM is installed.}

function EmsStatusOK : Boolean;
  {-Returns true if the EMM reports its status as being OK.}

function EmsPagesAvail : Word;
 {-Returns the number of available pages from the expanded memory manager,
   or EmsErrorCode in case of error.}

function EmsTotalPages : Word;
 {-Returns total number of pages of EMS memory, including allocated pages,
   or EmsErrorCode in case of error.}

function EmsPageFramePtr : Pointer;
  {-Returns the page frame base address as a pointer to the page frame.}

function AllocateEmsPages(NumPages : Word) : Word;
 {-Allocates the indicated number of pages and returns a handle.
   Returns EmsErrorCode in case of error.}

function MapEmsPage(Handle, LogicalPage : Word; PhysicalPage : Byte) : Boolean;
 {-Maps the specified LogicalPage associated with Handle into PhysicalPage
   (0-3). Returns true if successful.}

function DeallocateEmsHandle(Handle : Word) : Boolean;
  {-Deallocates the indicated handle and the memory associated with it.}

function EmsVersion : Byte;
 {-Returns a BCD version number of the EMM handle. To check for version 3.2
   or greater for example, use: 'if EmsVersion >= $32 then'. Returns 0 in
   case of error.}

function SaveEmsContext(Handle : Word) : Boolean;
 {-Saves the EMM context for resident programs. The handle passed must have
   been allocated with a call to AllocateEmsPages. Returns true if
   successful.}

function RestoreEmsContext(Handle : Word) : Boolean;
 {-Restores the mapping context of the EMM driver for the handle specified.
   The handle should the same one used in a prior call to SaveEmsContext.
   Returns true if successful.}

function EmsActiveHandles : Word;
  {-Returns the number of active EMS handles, EmsErrorCode in case of error}

function EmsPagesOwned(Handle : Word) : Word;
  {-Returns the number of pages owned by Handle, or EmsErrorCode in case of error.}

  {==========================================================================}

implementation

  {$L TPEMS.OBJ}

  function EmsStatusOK : Boolean; external;
  function EmsPagesAvail : Word; external;
  function EmsTotalPages : Word; external;
  function EmsPageFramePtr : Pointer; external;
  function AllocateEmsPages(NumPages : Word) : Word; external;
  function MapEmsPage(Handle, LogicalPage : Word; PhysicalPage : Byte) : Boolean;
  external;
  function DeallocateEmsHandle(Handle : Word) : Boolean; external;
  function EmsVersion : Byte; external;
  function SaveEmsContext(Handle : Word) : Boolean; external;
  function RestoreEmsContext(Handle : Word) : Boolean; external;
  function EmsActiveHandles : Word; external;
  function EmsPagesOwned(Handle : Word) : Word; external;

  function EmsInstalled : Boolean;
    {-Returns true if the Expanded Memory Manager is installed.}
  var
    F : file;
  begin
    Assign(F, 'EMMXXXX0');
    Reset(F);
    if IoResult = 0 then begin
      EmsInstalled := True;
      Close(F);
    end
    else
      EmsInstalled := False;
  end;

end.
