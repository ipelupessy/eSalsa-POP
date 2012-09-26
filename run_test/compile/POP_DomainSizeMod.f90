!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

 module POP_DomainSizeMod

!BOP
! !MODULE: POP_DomainSizeMod
!
! !DESCRIPTION:
! This module contains parameters for the global model domain size
! decomposition block size. It is used by the domain and block
! modules for decomposing the model domain across processors.
!
! !REVISION HISTORY:
! SVN:$Id: POP_DomainSizeMod.F90.test 12 2006-08-15 19:57:39Z $
! 2006-08-14: Phil Jones
! New domain size module following new naming conventions

! !USES:

   use POP_KindsMod

   implicit none
   private
   save

! !DEFINED PARAMETERS:

   integer (POP_i4), parameter, public :: & ! model size parameters
      POP_nxGlobal = 3600 ,&! extent of horizontal axis in i direction
      POP_nyGlobal = 2400 ,&! extent of horizontal axis in j direction
      POP_km = 42 ,&! number of vertical levels
! POP_nxGlobal = 192 ,&! extent of horizontal axis in i direction
! POP_nyGlobal = 128 ,&! extent of horizontal axis in j direction
! POP_km = 20 ,&! number of vertical levels
      POP_nt = 2 ! total number of tracers

   integer (POP_i4), parameter, public :: &
      POP_blockSizeX = 900, &! size of block in first horizontal dimension
      POP_blockSizeY = 600 ! size of block in second horizontal dimension

   !*** The model will inform the user of the correct
   !*** values for the parameters below. A value higher than
   !*** necessary will not cause the code to fail, but will
   !*** allocate more memory than is necessary. A value that
   !*** is too low will cause the code to exit.
   !*** A good initial guess is found using
   !*** max=(nx_global/block_size_x)*(ny_global/block_size_y)/
   !*** num_procs

   integer (POP_i4), parameter, public :: &
      POP_maxBlocksClinic = 1, &! max number of blocks per processor
      POP_maxBlocksTropic = 1 ! in each distribution

!EOP
!BOC
!EOC
!***********************************************************************

 end module POP_DomainSizeMod

!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
