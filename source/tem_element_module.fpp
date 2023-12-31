! Copyright (c) 2012 Manuel Hasert <m.hasert@grs-sim.de>
! Copyright (c) 2012-2013, 2015 Harald Klimach <harald.klimach@uni-siegen.de>
! Copyright (c) 2012-2013 Melven Zoellner <yameta@freenet.de>
! Copyright (c) 2012-2013 Simon Zimny <s.zimny@grs-sim.de>
! Copyright (c) 2012, 2016 Kannan Masilamani <kannan.masilamani@uni-siegen.de>
! Copyright (c) 2014 Kartik Jain <kartik.jain@uni-siegen.de>
! Copyright (c) 2015 Jiaxing Qi <jiaxing.qi@uni-siegen.de>
! Copyright (c) 2016 Tobias Schneider <tobias1.schneider@student.uni-siegen.de>
! Copyright (c) 2016 Peter Vitt <peter.vitt2@uni-siegen.de>
!
! Redistribution and use in source and binary forms, with or without
! modification, are permitted provided that the following conditions are met:
!
! 1. Redistributions of source code must retain the above copyright notice, this
! list of conditions and the following disclaimer.
!
! 2. Redistributions in binary form must reproduce the above copyright notice,
! this list of conditions and the following disclaimer in the documentation
! and/or other materials provided with the distribution.
!
! THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
! AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
! IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
! DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
! FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
! DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
! SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
! CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
! OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
! OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  ! See copyright notice in the COPYRIGHT file.
! ****************************************************************************** !
!> This module  provides descriptions for elements
!!
?? include 'arrayMacros.inc'
module tem_element_module

  ! include treelm modules
  use env_module,            only: long_k, minLength, zeroLength
  use tem_dyn_array_module,  only: dyn_longArray_type, init, append, expand,   &
    &                              destroy, truncate, SortedPosOfVal,          &
    &                              PositionOfVal
  use tem_grow_array_module, only: grw_longArray_type, truncate, destroy,      &
    &                              grw_logicalArray_type, init, append, expand,&
    &                              grw_intArray_type
  use tem_arrayofarrays_module, only: grw_dynlongArray_type, init, append, expand, &
    &                                 truncate, destroy
  use tem_stencil_module,    only: tem_stencilElement_type, tem_stencil_dump,  &
    &                              grw_stencilElementArray_type, init, append, &
    &                              truncate, destroy

  implicit none

  private

  public :: tem_element_type
  public :: tem_element_dump
  public :: print_nElems
  !> dynamic array of variable types
  public :: init, destroy, append, expand, getSize, getReqSize, &
    &       PositionOfVal, sortedPosOfVal, truncate, changeType
  public :: placeAt, empty

  public :: tem_eTypeOfId

  public :: eT_fluid, eT_halo, eT_nonExisting
  public :: eT_ghostFromCoarser, eT_ghostFromFiner
  public :: eT_sacrificed
  public :: eT_distributedGhostFromFiner
  public :: eT_undefined
  public :: eT_minRelevant, eT_maxRelevant
  public :: eT_minNumber, eT_maxNumber
  public :: eT_labels

  integer, parameter :: eT_undefined                      = -1
  integer, parameter :: eT_nonExisting                    =  0
  integer, parameter :: eT_fluid                          =  1
  integer, parameter :: eT_ghostFromCoarser               =  2
  integer, parameter :: eT_ghostFromFiner                 =  3
  integer, parameter :: eT_halo                           =  4
  integer, parameter :: eT_distributedGhostFromFiner      =  5
  !> Element properties which are created while adaptive refinement
  integer, parameter :: eT_sacrificed                     =  6
  integer, parameter :: eT_newFluid                       =  7
  !> eType integer values must be in the range of
  !! eT_minNumber <= eT_val <= eT_maxNumber
  integer, parameter :: eT_minNumber                      = -1
  integer, parameter :: eT_maxNumber                      = 7
  !> Relevant number of element types.
  !! As the distributed ghost from finer are in the assemble list step collapsed
  !! with the normal ghosFromFiner, only eType = 1 to 4 needs to be treated
  !! afterwards
  integer, parameter :: eT_minRelevant      = 1
  integer, parameter :: eT_maxRelevant      = 4

  !> Array of element type labels
  !! To use it, one can do the following:
  !! write(*,*) trim(eT_labels(levelDesc( level )%elem%eType%val( tPos )))
  character(len=12), parameter :: eT_labels(eT_minNumber:eT_maxNumber) = &
    &          [  '   undefined', &
    &             ' nonExisting', &
    &             '       fluid', &
    &             'gFromCoarser', &
    &             '  gFromFiner', &
    &             '        halo', &
    &             ' dgFromFiner', &
    &             '  sacrificed', &
    &             '    newFluid' ]

?? copy :: GA_decltxt(grw_stencilElement, type(grw_stencilElementArray_type))

  ! The tem_element_type contains the attributes of an element
  ! inside the level descriptor (usually).
  type tem_element_type
    !> Tree ID
    type(dyn_longArray_type)                :: tID
    !> Property
    type(grw_longArray_type)                :: property
    !> element type:
    !!   fluid,
    !!   ghostFromCoarser,
    !!   ghostFromFiner,
    !!   halo
    type(grw_intArray_type)                 :: eType
    !> Pointer to the original treeID list
    !! It should have the same size of tree
    !! It is destroyed in assemble_lists
    type(grw_intArray_type)                 :: pntTID
    !> Stencils defined for this element
    type(grw_grw_stencilElementArray_type ) :: stencil
    !> neighbor treeIDs coming from the stencil definitions
    !! each element has a list of neighbors, so this is an array of array
    type(grw_dynlongArray_type )            :: neighID
    !> source partition (starts at 1)
    type(grw_intArray_type)                 :: sourceProc
    !> nesting (only relevant for halos, to include their neighborhood)
    type(grw_intArray_type)                 :: haloNesting
    !> does this element need an update
    type(grw_logicalArray_type)             :: needsUpdate

    !> number of various types elements
    integer :: nElems( eT_minNumber:eT_maxNumber )

  end type tem_element_type

  interface init
    module procedure init_element
  end interface

  interface append
    module procedure append_element
  end interface

  interface truncate
    module procedure truncate_element
  end interface

  interface destroy
    module procedure destroy_element
  end interface

  interface getSize
    module procedure getSize_element
  end interface

  interface getReqSize
    module procedure getReqSize_element
  end interface

  interface changeType
    module procedure changeType_element
    module procedure changeType_element_vec
  end interface

  contains

! ****************************************************************************** !
  !> Include the subroutines for the dynamic array.
  !!
?? copy :: GA_impltxt(grw_stencilElement, type(grw_stencilElementArray_type))

! ****************************************************************************** !
  !> initialize an element and optionally set contents
  !!
  subroutine init_element( me, length )
    ! ---------------------------------------------------------------------------
    type( tem_element_type ), intent(out) :: me
    integer, intent(in), optional :: length
    ! ---------------------------------------------------------------------------
    call init( me = me%tID, length = length )
    call init( me = me%property, length = length )
    call init( me = me%eType, length = length )
    call init( me = me%pntTID, length = length )
    call init( me = me%stencil, length = length )
    call init( me = me%neighID, length = length )
    call init( me = me%sourceProc, length = length )
    call init( me = me%haloNesting, length = length )
    call init( me = me%needsUpdate, length = length )

    me%nElems = 0

  end subroutine init_element
! ****************************************************************************** !


! ****************************************************************************** !
  !> truncate all the lists in the element object
  !!
  subroutine truncate_element( me )
    ! ---------------------------------------------------------------------------
    !> element object
    type( tem_element_type ), intent(inout) :: me
    ! ---------------------------------------------------------------------------
    integer :: iVal
    ! ---------------------------------------------------------------------------
    call truncate( me = me%tID )
    call truncate( me = me%property )
    call truncate( me = me%eType )
    call truncate( me = me%pntTID )
    call truncate( me = me%stencil )
    do iVal = 1, me%stencil%nVals
      call truncate( me = me%stencil%val( iVal ) )
    end do
    call truncate( me = me%neighID )
    do iVal = 1, me%neighID%nVals
      call truncate( me = me%neighID%val( iVal ) )
      deallocate( me%neighID%val(iVal)%sorted)
    end do
    call truncate( me = me%sourceProc )
    call truncate( me = me%haloNesting )
    call truncate( me = me%needsUpdate )

  end subroutine truncate_element
! ****************************************************************************** !


! ****************************************************************************** !
  !> return the number of actual used memory (bytes) per element
  !!
  subroutine getReqSize_element( me, elemSize )
    ! ---------------------------------------------------------------------------
    !> element object
    type( tem_element_type ), intent(inout) :: me
    !> number of total entries to be returned
    integer(kind=long_k), intent(out) :: elemSize
    ! ---------------------------------------------------------------------------
    integer :: iVal, nSize
    ! ---------------------------------------------------------------------------
    elemSize = 0
    elemSize = elemSize + int( me%tID%nVals*12, kind=long_k)
    elemSize = elemSize + int( me%property%nVals*8, kind=long_k)
    elemSize = elemSize + int( me%eType%nVals*4, kind=long_k)
    elemSize = elemSize + int( me%pntTID%nVals*4, kind=long_k)

    do iVal = 1, me%stencil%nVals
      if( me%stencil%val( iVal )%nVals > 0 ) then
        nSize = size( me%stencil%val( iVal )%val(1)%tIDpos )*8
      else
        nSize = 0
      end if
      elemSize = elemSize + int( me%stencil%val(iVal)%nVals*nSize, kind=long_k)
    end do

    do iVal = 1, me%neighID%nVals
      elemSize = elemSize + int( me%neighID%val( iVal )%nVals*12, kind=long_k)
    end do

    elemSize = elemSize + int( me%sourceProc%nVals*4, kind=long_k)
    elemSize = elemSize + int( me%haloNesting%nVals*4, kind=long_k)
    elemSize = elemSize + int( me%needsUpdate%nVals*4, kind=long_k)

  end subroutine getReqSize_element
! ****************************************************************************** !


! ****************************************************************************** !
  !> return the number of total allocated memory (bytes) per element
  !!
  subroutine getSize_element( me, elemSize )
    ! ---------------------------------------------------------------------------
    !> element object
    type( tem_element_type ), intent(inout) :: me
    !> number of total entries to be returned
    integer(kind=long_k), intent(out) :: elemSize
    ! ---------------------------------------------------------------------------
    integer :: iVal, nSize
    ! ---------------------------------------------------------------------------
    elemSize = 0
    elemSize = elemSize + int( me%tID%containerSize*12, kind=long_k)
    elemSize = elemSize + int( me%property%containerSize*8, kind=long_k)
    elemSize = elemSize + int( me%eType%containerSize*4, kind=long_k)
    elemSize = elemSize + int( me%pntTID%containerSize*4, kind=long_k)

    do iVal = 1, me%stencil%nVals
      if( me%stencil%val( iVal )%nVals .gt. 0 ) then
        nSize = size( me%stencil%val( iVal )%val(1)%tIDpos )*8
      else
        nSize = 0
      end if
      elemSize = elemSize                                                      &
        &      + int( me%stencil%val( iVal )%containerSize*nSize, kind=long_k)
    end do

    do iVal = 1, me%neighID%nVals
      elemSize = elemSize                                                      &
        &      + int( me%neighID%val( iVal )%containerSize*12, kind=long_k)
    end do

    elemSize = elemSize + int( me%sourceProc%containerSize*4, kind=long_k)
    elemSize = elemSize + int( me%haloNesting%containerSize*4, kind=long_k)
    elemSize = elemSize + int( me%needsUpdate%containerSize*4, kind=long_k)

  end subroutine getSize_element
! ****************************************************************************** !


! ****************************************************************************** !
  !> destroy all the lists in the element object
  !!
  subroutine destroy_element( me )
    ! ---------------------------------------------------------------------------
    !> element object
    type( tem_element_type ), intent(inout) :: me
    ! ---------------------------------------------------------------------------
    integer :: iVal
    ! ---------------------------------------------------------------------------
    call destroy( me = me%tID )
    call destroy( me = me%property )
    call destroy( me = me%eType )
    call destroy( me = me%pntTID )
    do iVal = 1, me%stencil%nVals
      call destroy( me = me%stencil%val( iVal ) )
    end do
    call destroy( me = me%stencil )
    do iVal = 1, me%neighID%nVals
      call destroy( me = me%neighID%val( iVal ) )
    end do
    call destroy( me = me%neighID )
    call destroy( me = me%sourceProc )
    call destroy( me = me%haloNesting )
    call destroy( me = me%needsUpdate )

  end subroutine destroy_element
! ****************************************************************************** !


! ****************************************************************************** !
  !> append an element with its treeID, property, element type,
  !! position in Tree, position in boundary_ID, number of neighbors,
  !! procID
  !!
  subroutine append_element( me, tID, property, eType, pntTID, &
    &                        sourceProc, nNeighIDs, haloNesting, needsUpdate,  &
    &                        stencilElements, pos, wasAdded )
    ! ---------------------------------------------------------------------------
    !> element object
    type( tem_element_type ), intent(inout)     :: me
    !> element treeID
    integer(kind=long_k), intent(in)            :: tID
    !> position of treeID
    integer, intent(out)                        :: pos
    !> property associated with the treeID
    integer(kind=long_k), intent(in), optional  :: property
    !> element type
    integer, intent(in), optional               :: eType
    !> count of this type
    ! integer, intent(inout)                      :: nElems
    !> pointer of the treeID
    integer, intent(in), optional               :: pntTID
    !> nesting level for haloElems
    integer, intent(in), optional               :: haloNesting
    !> the procID which is adding the element
    integer, intent(in), optional               :: sourceProc
    !>
    logical, intent(in), optional               :: needsUpdate
    !> number of neighbors
    integer, intent(in), optional               :: nNeighIDs
    !>
    logical, intent(out),optional               :: wasAdded
    !>
    type(tem_stencilElement_type), intent(in), optional :: stencilElements(:)
    ! ---------------------------------------------------------------------------
    integer :: iElem
    integer :: neighIDsize
    logical :: wasAdded_loc
    type(grw_stencilElementArray_type) :: stencilElementArray
    type(dyn_longArray_type) :: tneighID
    ! ---------------------------------------------------------------------------
    call append( me = me%tID, val = tID, pos = pos, wasAdded = wasAdded_loc )
    if( wasAdded_loc ) then
      ! was not in list before, but added. Add all further handed in contents.
      if( present( property )) then
        call append( me = me%property, val = property )
      else
        call append( me = me%property, val = 0_long_k )
      end if

      if( present( eType )) then
        if ( tem_eTypeIsValid( eType ) ) then
          call append( me = me%eType, val = eType )
          me%nElems( eType ) = me%nElems( eType ) + 1
        else
          write(*,"(A,I0)") 'Found eType is NOT valid!', &
            &               ', TreeID: ', tID, &
            &               ',  eType: ', eType
        end if
      else
        call append( me = me%eType, val = eT_undefined)
      end if

      if( present( pntTID )) then
        call append( me = me%pntTID, val = pntTID )
      else
        call append( me = me%pntTID, val = -1 )
      end if

      if( present( sourceProc )) then
        call append( me = me%sourceProc, val = sourceProc )
      else
        call append( me = me%sourceProc, val = -1 )
      end if

      if( present( haloNesting )) then
        call append( me = me%haloNesting, val = haloNesting )
      else
        call append( me = me%haloNesting, val = 1 )
      end if

      if( present( needsUpdate )) then
        call append( me = me%needsUpdate, val = needsUpdate )
      else
        call append( me = me%needsUpdate, val = .false. )
      end if

      call init( me = stencilElementArray, length = 1 )
      call append( me = me%stencil, val = stencilElementArray )
      if( present( stencilElements )) then
        do iElem = 1, size( stencilElements )
          if( stencilElements(iElem)%QQN > 0 )                         &
            &           call append( me  = me%stencil%val( pos ), &
            &                        val = stencilElements( iElem ))
        end do
      end if

      if( present( nNeighIDs )) then
        neighIDsize = max( 0, nNeighIDs )
      else
        neighIDsize = 1
      end if
      ! add empty dynamic array of length neighIDsize for the neighbors
      call init( me = tNeighID, length = neighIDsize )
      call append( me = me%neighID, val = tNeighID )

    end if ! was added to tID list

    if( present( wasAdded )) then
      wasAdded = wasAdded_loc
    end if

  end subroutine append_element
! ****************************************************************************** !


! ****************************************************************************** !
  !> Write element information to disk
  subroutine tem_element_dump( me, elemPos, nUnit, compact, header, stencil )
    ! ---------------------------------------------------------------------------
    !> element object
    type( tem_element_type ), intent(in) :: me
    !>
    integer, intent(in) :: elemPos
    !>
    integer, intent(in) :: nUnit
    !>
    logical, intent(in), optional :: compact
    !>
    logical, intent(in), optional :: header
    !> Whether to write stencil information
    logical, intent(in), optional :: stencil
    ! ---------------------------------------------------------------------------
    integer :: iStencil
    logical :: locCompact, locStencil
    ! ---------------------------------------------------------------------------

    locStencil = .false.
    if( present( stencil )) then
      locStencil = stencil
    endif

    if( present( compact )) then
      locCompact = compact
    else
      locCompact = .true.
    endif

    if( locCompact ) then
      ! in compact format
      if( present( header )) then
        if( header ) then
          write(nUnit,'(a10,6(a8))') 'treeID', 'prop', 'eType', 'process',&
            &                        'haloNst', 'pntTID', 'stencil'
        endif
      endif
      write(nUnit,'(I10,I8,A12,4I8)') me%tID%val( elemPos ),                  &
        &                      me%property%val( elemPos ),                     &
        &                      eT_labels(me%eType%val( elemPos )),             &
        &                      me%sourceProc%val( elemPos ),                   &
        &                      me%haloNesting%val( elemPos ),                  &
        &                      me%pntTID%val( elemPos ),                       &
        &                      me%stencil%val( elemPos )%nVals
    else
      ! in detailed format
      write(nUnit,"(A)")    '---------------------------------------------'
      write(nUnit,"(A)")    'Element'
      write(nUnit,"(A,I0)") '   treeID      ', me%tID%val( elemPos )
      write(nUnit,"(A,I0)") '   property    ', me%property%val( elemPos )
      write(nUnit,"(A,A)")  '   eType       ', eT_labels(me%eType%val( elemPos ))
      write(nUnit,"(A,I0)") '   srcProc     ', me%sourceProc%val( elemPos )
      write(nUnit,"(A,I0)") '   haloNesting ', me%haloNesting%val( elemPos )
      write(nUnit,"(A)")    '---------------------------------------------'
    end if

    if ( locStencil ) then
      do iStencil = 1, me%stencil%val( elemPos )%nVals
        call tem_stencil_dump(                                         &
          &       me      = me%stencil%val( elemPos )%val( iStencil ), &
          &       nUnit   = nUnit,                                     &
          &       neighID = me%neighID%val( elemPos )%val,             &
          &       tIDonly = .false. )
      end do
    end if

  end subroutine tem_element_dump
! ****************************************************************************** !

! ****************************************************************************** !
  !> Return the element type of a treeID .
  !!
  function tem_eTypeOfId( tID, me ) result( eType )
    ! ---------------------------------------------------------------------------
    !> the element you are looking for
    integer(kind=long_k), intent(in) :: tID
    !> the descriptor you use for searching
    type(tem_element_type), intent(in) :: me
    !> element type
    integer :: eType
    ! ---------------------------------------------------------------------------
    integer :: pos
    ! ---------------------------------------------------------------------------
    eType = eT_undefined
    pos = PositionOfVal( me  = me%tID, val = tID )
    if( pos > 0 ) then
      eType = me%eType%val( pos )
    end if

  end function tem_eTypeOfId
! ****************************************************************************** !


! ****************************************************************************** !
  pure function tem_eTypeIsValid( eT ) result( isValid )
    ! ---------------------------------------------------------------------------
    integer, intent(in) :: eT
    logical :: isValid
    ! ---------------------------------------------------------------------------

    if ( (eT >= eT_minNumber) .and. (eT <= eT_maxNumber) ) then
      isValid = .true.
    else
      isValid = .false.
    end if
  end function tem_eTypeIsValid
! ****************************************************************************** !

! ****************************************************************************** !
  subroutine changeType_element( me, elemPos, new_eType )
    ! ---------------------------------------------------------------------------
    type(tem_element_type), intent(inout) :: me
    integer, intent(in) :: elemPos
    integer, intent(in) :: new_eType
    ! ---------------------------------------------------------------------------
    integer :: old_eType
    ! ---------------------------------------------------------------------------

    if ( tem_eTypeIsValid(new_eType) ) then
      old_eType = me%eType%val( elemPos )
      me%eType%val( elemPos ) = new_eType
      me%nElems(new_eType) = me%nElems(new_eType) + 1
      me%nElems(old_eType) = me%nElems(old_eType) - 1
    end if

  end subroutine changeType_element
! ****************************************************************************** !

! ****************************************************************************** !
  subroutine changeType_element_vec( me, nElems, elemPos, new_eType )
    ! ---------------------------------------------------------------------------
    type(tem_element_type), intent(inout) :: me
    integer, intent(in) :: nElems
    integer, intent(in) :: elemPos(:)
    integer, intent(in) :: new_eType
    ! ---------------------------------------------------------------------------
    integer :: old_eType, iElem
    ! ---------------------------------------------------------------------------

    if ( tem_eTypeIsValid(new_eType) ) then
      do iElem = 1, nElems
        old_eType = me%eType%val( elemPos(iElem) )
        me%eType%val( elemPos(iElem) ) = new_eType
        me%nElems(new_eType) = me%nElems(new_eType) + 1
        me%nElems(old_eType) = me%nElems(old_eType) - 1
      end do
    end if

  end subroutine changeType_element_vec
! ****************************************************************************** !

! ****************************************************************************** !
  subroutine print_nElems( nElems, outUnit )
    ! ---------------------------------------------------------------------------
    integer, intent(in) :: nElems(eT_minRelevant:eT_maxRelevant)
    integer, intent(in) :: outUnit
    ! ---------------------------------------------------------------------------
    integer :: iType
    ! ---------------------------------------------------------------------------

    do iType = eT_minRelevant, eT_maxRelevant
      write(outUnit,"(A,I0)") eT_labels(iType)//': ', nElems( iType )
    end do

  end subroutine
! ****************************************************************************** !

end module tem_element_module
! *******************************************************************************
