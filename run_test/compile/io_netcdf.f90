!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

 module io_netcdf

!BOP
! !MODULE: io_netcdf
! !DESCRIPTION:
! This module provides a generic input/output interface
! for writing arrays in netCDF format.
!
! !REVISION HISTORY:
! SVN:$Id: io_netcdf.F90 17212 2009-07-20 23:01:42Z njn01 $

! !USES:

   use POP_KindsMod
   use POP_IOUnitsMod

   use kinds_mod
   use domain_size
   use domain
   use constants
   use communicate
   use broadcast
   use gather_scatter
   use exit_mod
   use io_types
   use io_tools
   use netcdf

   implicit none
   private
   save

! !PUBLIC MEMBER FUNCTIONS:

   public :: open_read_netcdf, &
             open_netcdf, &
             close_netcdf, &
             define_field_netcdf, &
             read_field_netcdf, &
             write_field_netcdf, &
             define_nstd_netcdf, &
             write_nstd_netcdf

!EOP
!BOC


!-----------------------------------------------------------------------
!
! module variables
!
!-----------------------------------------------------------------------


!EOC
!***********************************************************************

 contains

!***********************************************************************
!BOP
! !IROUTINE: open_read_netcdf
! !INTERFACE:

 subroutine open_read_netcdf(data_file)

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (inout) :: data_file

! !DESCRIPTION:
! This routine opens a netcdf data file and extracts global file
! attributes.
!
! !REVISION HISTORY:
! same as module

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------


   character (char_len) :: &
      path ! filename to read

   character (80) :: &
      work_line, &! temporary to use for parsing file lines
      att_name ! temporary to use for attribute names

   integer (i4) :: &
      iostat, &! status flag
      ncid, &! netCDF file id
      nsize, &! size parameter returned by inquire function
      n, &! loop index
      itype, &! netCDF data type
      att_ival, &! netCDF data type
      num_atts ! number of global attributes

   logical (log_kind) :: &
      att_lval ! temp space for logical attribute

   real (r4) :: &
      att_rval ! temp space for real attribute

   real (r8) :: &
      att_dval ! temp space for double attribute

   logical (log_kind) :: &
      attrib_error ! error flag for reading attributes

!-----------------------------------------------------------------------
!
! set the readonly flag in the data file descriptor
!
!-----------------------------------------------------------------------

   data_file%readonly = .true.

!-----------------------------------------------------------------------
!
! open the netCDF file
!
!-----------------------------------------------------------------------


   iostat = nf90_noerr
   data_file%id = 0

   if (my_task == master_task) then
      path = trim(data_file%full_name)
      iostat = nf90_open(path=trim(path), mode=nf90_nowrite, ncid=ncid)
      call check_status(iostat)
   endif

   call broadcast_scalar(iostat, master_task)
   if (iostat /= nf90_noerr) then
      write(stdout,*) 'filename = ', trim(data_file%full_name)
      call exit_POP(sigAbort,'error opening netCDF file for reading')
   endif

   call broadcast_scalar(ncid, master_task)
   data_file%id(1) = ncid

!-----------------------------------------------------------------------
!
! determine number of global file attributes
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then
      iostat = nf90_Inquire(ncid, nAttributes = num_atts)
   end if

   call broadcast_scalar(iostat, master_task)
   if (iostat /= nf90_noerr) &
      call exit_POP(sigAbort, &
                    'error getting number of netCDF global attributes')

   call broadcast_scalar(num_atts, master_task)

!-----------------------------------------------------------------------
!
! now read each attribute and set attribute values
!
!-----------------------------------------------------------------------

   do n=1,num_atts

      !***
      !*** get attribute name
      !***

      att_name = char_blank
      if (my_task == master_task) then
         iostat = nf90_inq_attname(ncid, NF90_GLOBAL, n, att_name)
      endif

      call broadcast_scalar(iostat, master_task)
      if (iostat /= nf90_noerr) &
         call exit_POP(sigAbort, &
                       'error getting netCDF global attribute name')

      call broadcast_scalar(att_name, master_task)

      !***
      !*** check to see if name matches any of the standard file
      !*** attributes
      !***

      select case(trim(att_name))

      case('title')

         data_file%title = char_blank

         if (my_task == master_task) then
            iostat = nf90_inquire_attribute(ncid, NF90_GLOBAL, &
                                            'title', len=nsize)

            if (iostat == nf90_noerr) then
               if (nsize <= len(data_file%title)) then
                  iostat = nf90_get_att(ncid, NF90_GLOBAL, 'title', &
                                        data_file%title(1:nsize))
                  call check_status(iostat)
               else
                  call document('open_read_netcdf', 'nsize', nsize)
                  call document('open_read_netcdf', 'len(data_file%title)', &
                                len(data_file%title))
                  write(stdout,*) 'string too short; not enough room to read title from ' /&
                                  &/ trim(path)
               endif
            endif
         endif

         call broadcast_scalar(iostat, master_task)
         if (iostat /= nf90_noerr) then
            call exit_POP(sigAbort, &
                    'Error reading title from netCDF file')
         endif

         call broadcast_scalar(data_file%title, master_task)

      case('history')

         data_file%history = char_blank
         if (my_task == master_task) then
            iostat = nf90_inquire_attribute(ncid, NF90_GLOBAL, &
                                            'history', len=nsize)
            if (iostat == nf90_noerr) then
               if (nsize <= len(data_file%history)) then
                  iostat = nf90_get_att(ncid, NF90_GLOBAL, 'history', &
                                        data_file%history(1:nsize))
                  call check_status(iostat)
               else
                  call document('open_read_netcdf', 'nsize', nsize)
                  call document('open_read_netcdf', 'len(data_file%history)', &
                                len(data_file%history))
                  write(stdout,*) 'string too short; not enough room to read history attribute from ' /&
                                  &/ trim(path)
               endif
            endif
         endif

         call broadcast_scalar(iostat, master_task)
         if (iostat /= nf90_noerr) then
            call exit_POP(sigAbort, &
                    'Error reading history from netCDF file')
         endif

         call broadcast_scalar(data_file%history, master_task)

      case('conventions')

         data_file%conventions = char_blank
         if (my_task == master_task) then
            iostat = nf90_inquire_attribute(ncid, NF90_GLOBAL, &
                                            'conventions', len=nsize)
            if (iostat == nf90_noerr) then
               if (nsize <= len(data_file%conventions)) then
                  iostat = nf90_get_att(ncid, NF90_GLOBAL, 'conventions', &
                                        data_file%conventions(1:nsize))
                  call check_status(iostat)
               else
                  call document('open_read_netcdf', 'nsize', nsize)
                  call document('open_read_netcdf', 'len(data_file%conventions)', &
                                len(data_file%conventions))
                  write(stdout,*) 'string too short; not enough room to read conventions from ' /&
                                  &/ trim(path)
               endif
            endif
         endif

         call broadcast_scalar(iostat, master_task)
         if (iostat /= nf90_noerr) then
            call exit_POP(sigAbort, &
                    'Error reading conventions from netCDF file')
         endif

         call broadcast_scalar(data_file%conventions, master_task)

      case default

         !***
         !*** if does not match any of the standard file attributes
         !*** add the attribute to the datafile
         !***

         if (my_task == master_task) then
            iostat = nf90_Inquire_Attribute(ncid, NF90_GLOBAL, &
                                            trim(att_name), &
                                            xtype = itype, &
                                            len = nsize)
         endif

         call broadcast_scalar(iostat, master_task)
         if (iostat /= nf90_noerr) then
            call exit_POP(sigAbort, &
                    'Error reading netCDF file attribute')
         endif

         call broadcast_scalar(itype, master_task)

         select case (itype)

         case (NF90_CHAR)
            work_line = char_blank
            call broadcast_scalar(nsize, master_task)
            if (my_task == master_task) then
               if (nsize <= len(work_line)) then
                  iostat = nf90_get_att(ncid, NF90_GLOBAL, &
                                        trim(att_name), &
                                        work_line(1:nsize))
               else
                  call document('open_read_netcdf', 'nsize', nsize)
                  call document('open_read_netcdf', 'len(work_line)', &
                                len(work_line))
                  write(stdout,*) 'string too short; not enough room to read ' /&
                                  &/ trim(att_name) /&
                                  &/ ' from ' /&
                                  &/ trim(path)
               endif
            endif
            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                    'Error reading netCDF file attribute')
            endif

            call broadcast_scalar(work_line, master_task)
            call add_attrib_file(data_file, trim(att_name), &
                                            trim(work_line))

         case (NF90_INT)
            if (my_task == master_task) then
               iostat = nf90_get_att(ncid, NF90_GLOBAL, &
                                     trim(att_name), att_ival)
            endif
            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                    'Error reading netCDF file attribute')
            endif

            call broadcast_scalar(att_ival, master_task)
            if (att_name(1:4) == 'LOG_') then !*** attribute logical
               work_line = att_name
               work_line(1:4) = '    '
               att_name = adjustl(work_line)

               if (att_ival == 1) then
                  att_lval = .true.
               else
                  att_lval = .false.
               endif
               call add_attrib_file(data_file, trim(att_name), att_lval)

            else
               call add_attrib_file(data_file, trim(att_name), att_ival)
            endif

         case (NF90_FLOAT)
            if (my_task == master_task) then
               iostat = nf90_get_att(ncid, NF90_GLOBAL, &
                                     trim(att_name), att_rval)
            endif
            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                    'Error reading netCDF file attribute')
            endif

            call broadcast_scalar(att_rval, master_task)
            call add_attrib_file(data_file, trim(att_name), att_rval)


         case (NF90_DOUBLE)
            if (my_task == master_task) then
               iostat = nf90_get_att(ncid, NF90_GLOBAL, &
                                     trim(att_name), att_dval)
            endif
            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                    'Error reading netCDF file attribute')
            endif

            call broadcast_scalar(att_dval, master_task)
            call add_attrib_file(data_file, trim(att_name), att_dval)


         end select

      end select

   end do ! num_atts

!-----------------------------------------------------------------------
!EOC

 end subroutine open_read_netcdf

!***********************************************************************
!BOP
! !IROUTINE: open_netcdf
! !INTERFACE:

 subroutine open_netcdf(data_file)

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (inout) :: data_file

! !DESCRIPTION:
! This routine opens a data file for writing and
! writes global file attributes.
!
! !REVISION HISTORY:
! same as module

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   character (char_len) :: &
      path ! temp to use for filename

   character (255) :: &
      work_line ! temp to use for character manipulation

   integer (i4) :: &
      ncid, &! netCDF id for file
      iostat, &! status flag for netCDF function calls
      itmp, &! integer temp for equivalent logical attribute
      n, &! loop index
      ncvals, &! counter for number of character attributes
      nlvals, &! counter for number of logical attributes
      nivals, &! counter for number of integer attributes
      nrvals, &! counter for number of real attributes
      ndvals ! counter for number of double attributes

   logical (log_kind) :: &
      attrib_error ! error flag for reading attributes

!-----------------------------------------------------------------------
!
! open the netCDF file
!
!-----------------------------------------------------------------------

   iostat = nf90_noerr
   data_file%id = 0

   if (my_task==master_task) then
      path = trim(data_file%full_name)
      if (luse_nf_64bit_offset) then
        iostat = nf90_create(path=trim(path), cmode=NF90_64BIT_OFFSET, ncid=ncid)
      else
        iostat = nf90_create(path=trim(path), cmode=nf90_write, ncid=ncid)
      endif
      call check_status(iostat)
   endif

   call broadcast_scalar(iostat, master_task)
   if (iostat /= nf90_noerr) call exit_POP(sigAbort, &
                                           'Error opening file')

   call broadcast_scalar(ncid, master_task)
   data_file%id(1) = ncid
   data_file%ldefine = .true. ! file in netCDF define mode

!-----------------------------------------------------------------------
!
! define global file attributes
!
!-----------------------------------------------------------------------

   attrib_error = .false.

   if (my_task == master_task) then

      !*** standard attributes

      iostat = nf90_put_att(ncid, NF90_GLOBAL, 'title', &
                            trim(data_file%title))
      call check_status(iostat)
      if (iostat /= nf90_noerr) then
         write(stdout,*) 'Error writing TITLE to netCDF file'
         attrib_error = .true.
      endif

      iostat = nf90_put_att(ncid, NF90_GLOBAL, 'history', &
                            trim(data_file%history))
      call check_status(iostat)
      if (iostat /= nf90_noerr) then
         write(stdout,*) 'Error writing HISTORY to netCDF file'
         attrib_error = .true.
      endif

      iostat = nf90_put_att(ncid, NF90_GLOBAL, 'conventions', &
                            trim(data_file%conventions))
      call check_status(iostat)
      if (iostat /= nf90_noerr) then
         write(stdout,*) 'Error writing CONVENTIONS to netCDF file'
         attrib_error = .true.
      endif

      !*** additional attributes

      if (associated(data_file%add_attrib_cval)) then
         ncvals = size(data_file%add_attrib_cval)
      else
         ncvals = 0
      endif
      if (associated(data_file%add_attrib_lval)) then
         nlvals = size(data_file%add_attrib_lval)
      else
         nlvals = 0
      endif
      if (associated(data_file%add_attrib_ival)) then
         nivals = size(data_file%add_attrib_ival)
      else
         nivals = 0
      endif
      if (associated(data_file%add_attrib_rval)) then
         nrvals = size(data_file%add_attrib_rval)
      else
         nrvals = 0
      endif
      if (associated(data_file%add_attrib_dval)) then
         ndvals = size(data_file%add_attrib_dval)
      else
         ndvals = 0
      endif

      do n=1,ncvals
         work_line = data_file%add_attrib_cname(n)

         iostat = nf90_put_att(ncid, NF90_GLOBAL, trim(work_line), &
                               trim(data_file%add_attrib_cval(n)))
         call check_status(iostat)
         if (iostat /= nf90_noerr) then
            write(stdout,*) 'Error writing ',trim(work_line)
            attrib_error = .true.
         endif
      end do

      do n=1,nlvals
         work_line = 'LOG_'/&
                            &/data_file%add_attrib_lname(n)
         if (data_file%add_attrib_lval(n)) then
            itmp = 1
         else
            itmp = 0
         endif

         iostat = nf90_put_att(ncid, NF90_GLOBAL, trim(work_line), &
                               itmp)
         call check_status(iostat)
         if (iostat /= nf90_noerr) then
            write(stdout,*) 'Error writing ',trim(work_line)
            attrib_error = .true.
         endif
      end do

      do n=1,nivals
         work_line = data_file%add_attrib_iname(n)

         iostat = nf90_put_att(ncid, NF90_GLOBAL, trim(work_line), &
                               data_file%add_attrib_ival(n))
         call check_status(iostat)
         if (iostat /= nf90_noerr) then
            write(stdout,*) 'Error writing ',trim(work_line)
            attrib_error = .true.
         endif
      end do

      do n=1,nrvals
         work_line = data_file%add_attrib_rname(n)

         iostat = nf90_put_att(ncid, NF90_GLOBAL, trim(work_line), &
                               data_file%add_attrib_rval(n))
         call check_status(iostat)
         if (iostat /= nf90_noerr) then
            write(stdout,*) 'Error writing ',trim(work_line)
            attrib_error = .true.
         endif
      end do

      do n=1,ndvals
         work_line = data_file%add_attrib_dname(n)

         iostat = nf90_put_att(ncid, NF90_GLOBAL, trim(work_line), &
                               data_file%add_attrib_dval(n))
         call check_status(iostat)
         if (iostat /= nf90_noerr) then
            write(stdout,*) 'Error writing ',trim(work_line)
            attrib_error = .true.
         endif
      end do

   endif ! master task

   call broadcast_scalar(attrib_error, master_task)
   if (attrib_error) call exit_POP(sigAbort, &
                                   'Error writing file attributes')

!-----------------------------------------------------------------------
!EOC

 end subroutine open_netcdf

!***********************************************************************
!BOP
! !IROUTINE: close_netcdf
! !INTERFACE:

 subroutine close_netcdf(data_file)

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (inout) :: data_file

! !DESCRIPTION:
! This routine closes an open netcdf data file.
!
! !REVISION HISTORY:
! same as module

!EOP
!BOC
!-----------------------------------------------------------------------
!
! close a data file
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then
      call check_status(nf90_close(data_file%id(1)))
   end if

!-----------------------------------------------------------------------
!EOC

 end subroutine close_netcdf

!***********************************************************************
!BOP
! !IROUTINE: define_field_netcdf
! !INTERFACE:

 subroutine define_field_netcdf(data_file, io_field)

! !DESCRIPTION:
! This routine defines an io field for a netCDF file.
! When reading a file, the define routine will attempt to fill an
! io field structure with meta-data information from the netCDF file.
! When writing a file, it calls the appropriate netCDF routines
! to define all the field attributes and assign a field id.
!
! !REVISION HISTORY:
! same as module

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (inout) :: &
      data_file ! data file in which field contained

   type (io_field_desc), intent (inout) :: &
      io_field ! field descriptor for this field

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   character (80) :: &
      work_line, &! workspace for manipulating input string
      comp_line, &! comparison string
      att_name ! attribute name

   integer (i4) :: &
      iostat, &! status flag for netCDF calls
      ncid, &! file id for netcdf file
      varid, &! variable id for field
      ndims, &! number of dimensions
      dimid, &! dimension id
      n, &! loop index
      ncount, &! num additional attributes
      nsize, &! length of character strings
      itype, &! netCDF data type
      num_atts, &! number of variable attributes
      att_ival, &! temp for integer attribute
      ncvals, &! counter for number of character attributes
      nlvals, &! counter for number of logical attributes
      nivals, &! counter for number of integer attributes
      nrvals, &! counter for number of real attributes
      ndvals ! counter for number of double attributes

   logical (log_kind) :: &
      att_lval ! temp for logical attribute

   real (r4) :: &
      att_rval ! temp for real attribute

   real (r8) :: &
      att_dval ! temp for double attribute

   logical (log_kind) :: &
      define_error ! error flag


   define_error = .false.
   ncid = data_file%id(1)

!-----------------------------------------------------------------------
!
! make sure file has been opened
!
!-----------------------------------------------------------------------

   call check_file_open(data_file, 'define_field_netcdf')

!-----------------------------------------------------------------------
!
! for input files, get the variable id and determine number of field
! attributes
!
!-----------------------------------------------------------------------

   if (data_file%readonly) then
      if (my_task == master_task) then
         iostat = NF90_INQ_VARID(ncid, trim(io_field%short_name), &
                                 io_field%id)
         call check_status(iostat)
      endif
      call broadcast_scalar(iostat, master_task)
      if (iostat /= nf90_noerr) &
         call exit_POP(sigAbort, &
                   'Error finding field in netCDF input file')

      call broadcast_scalar(io_field%id, master_task)

      if (my_task == master_task) then
         iostat = NF90_Inquire_Variable(ncid,io_field%id,nAtts=num_atts)
         call check_status(iostat)
      endif
      call broadcast_scalar(iostat, master_task)
      if (iostat /= nf90_noerr) &
         call exit_POP(sigAbort, &
                   'Error getting attribute count for netCDF field')

      call broadcast_scalar(num_atts, master_task)

      !***
      !*** for each attribute, define standard attributes or add
      !*** attribute to io_field
      !***

      do n=1,num_atts

         !***
         !*** get attribute name
         !***

         att_name = char_blank
         if (my_task == master_task) then
            iostat = nf90_inq_attname(ncid, io_field%id, n, att_name)
         endif

         call broadcast_scalar(iostat, master_task)
         if (iostat /= nf90_noerr) &
            call exit_POP(sigAbort, &
                   'error getting netCDF field attribute name')

         call broadcast_scalar(att_name, master_task)

         !***
         !*** check to see if name matches any of the standard field
         !*** attributes
         !***

         select case(trim(att_name))

         case('long_name')

            io_field%long_name = char_blank

            if (my_task == master_task) then
               iostat = nf90_inquire_attribute(ncid, io_field%id, &
                                               'long_name', len=nsize)

               if (iostat == nf90_noerr) then
                  if (nsize <= len(io_field%long_name)) then
                     iostat = nf90_get_att(ncid, io_field%id, 'long_name', &
                                           io_field%long_name(1:nsize))
                     call check_status(iostat)
                  else
                     call document('define_field_netcdf', 'nsize', nsize)
                     call document('define_field_netcdf', 'len(io_field%long_name)', &
                                   len(io_field%long_name))
                     write(stdout,*) 'string too short; not enough room to read long_name of ' /&
                                     &/ trim(io_field%short_name) /&
                                     &/ ' from ' /&
                                     &/ trim(data_file%full_name)
                  endif
               endif
            endif

            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                   'Error reading long_name from netCDF file')
            endif

            call broadcast_scalar(io_field%long_name, master_task)

         case('units')

            io_field%units = char_blank

            if (my_task == master_task) then
               iostat = nf90_inquire_attribute(ncid, io_field%id, &
                                               'units', len=nsize)

               if (iostat == nf90_noerr) then
                  if (nsize <= len(io_field%units)) then
                     iostat = nf90_get_att(ncid, io_field%id, 'units', &
                                           io_field%units(1:nsize))
                     call check_status(iostat)
                  else
                     call document('define_field_netcdf', 'nsize', nsize)
                     call document('define_field_netcdf', 'len(io_field%units)', &
                                   len(io_field%units))
                     write(stdout,*) 'string too short; not enough room to read units of ' /&
                                     &/ trim(io_field%short_name) /&
                                     &/ ' from ' /&
                                     &/ trim(data_file%full_name)
                  endif
               endif
            endif

            call broadcast_scalar(io_field%units, master_task)

         case('coordinates')

            io_field%coordinates = char_blank

            if (my_task == master_task) then
               iostat = nf90_inquire_attribute(ncid, io_field%id, &
                                               'coordinates', len=nsize)

               if (iostat == nf90_noerr) then
                  if (nsize <= len(io_field%coordinates)) then
                     iostat = nf90_get_att(ncid, io_field%id, 'coordinates', &
                                           io_field%coordinates(1:nsize))
                     call check_status(iostat)
                  else
                     call document('define_field_netcdf', 'nsize', nsize)
                     call document('define_field_netcdf', 'len(io_field%coordinates)', &
                                   len(io_field%coordinates))
                     write(stdout,*) 'string too short; not enough room to read coordinates of ' /&
                                     &/ trim(io_field%short_name) /&
                                     &/ ' from ' /&
                                     &/ trim(data_file%full_name)
                  endif
               endif
            endif

            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                   'Error reading coordinates from netCDF file')
            endif

            call broadcast_scalar(io_field%coordinates, master_task)

         case('grid_loc')

            io_field%grid_loc = '    '

            if (my_task == master_task) then
               iostat = nf90_inquire_attribute(ncid, io_field%id, &
                                               'grid_loc', len=nsize)

               if (iostat == nf90_noerr) then
                  if (nsize <= len(io_field%grid_loc)) then
                     iostat = nf90_get_att(ncid, io_field%id, 'grid_loc', &
                                           io_field%grid_loc(1:nsize))
                     call check_status(iostat)
                  else
                     call document('define_field_netcdf', 'nsize', nsize)
                     call document('define_field_netcdf', 'len(io_field%grid_loc)', &
                                   len(io_field%grid_loc))
                     write(stdout,*) 'string too short; not enough room to read grid_loc of ' /&
                                     &/ trim(io_field%short_name) /&
                                     &/ ' from ' /&
                                     &/ trim(data_file%full_name)
                  endif
               endif
            endif

            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                   'Error reading grid_loc from netCDF file')
            endif

            call broadcast_scalar(io_field%grid_loc, master_task)


         case('missing_value')

            if (my_task == master_task) then
               iostat = nf90_get_att(ncid, io_field%id, &
                                     'missing_value', &
                                     io_field%missing_value)
               call check_status(iostat)
            endif

            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                   'Error reading missing_value from netCDF file')
            endif

            call broadcast_scalar(io_field%missing_value, master_task)

         case('missing_value_i')

            if (my_task == master_task) then
               iostat = nf90_get_att(ncid, io_field%id, &
                                     'missing_value_i', &
                                     io_field%missing_value_i)
               call check_status(iostat)
            endif

            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                   'Error reading missing_value_i from netCDF file')
            endif

            call broadcast_scalar(io_field%missing_value_i, master_task)


         case('valid_range')

            if (my_task == master_task) then
               iostat = nf90_get_att(ncid, io_field%id, &
                                     'valid_range', &
                                     io_field%valid_range)
               call check_status(iostat)
            endif

            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                   'Error reading valid_range from netCDF file')
            endif

            call broadcast_array(io_field%valid_range, master_task)


         case default

            !***
            !*** if does not match any of the standard file attributes
            !*** add the attribute to the datafile
            !***

            if (my_task == master_task) then
               iostat = nf90_Inquire_Attribute(ncid, io_field%id, &
                                               trim(att_name), &
                                               xtype = itype, &
                                               len = nsize)
            endif

            call broadcast_scalar(iostat, master_task)
            if (iostat /= nf90_noerr) then
               call exit_POP(sigAbort, &
                   'Error reading netCDF file attribute')
            endif

            call broadcast_scalar(itype, master_task)

            select case (itype)

            case (NF90_CHAR)
               work_line = char_blank
               call broadcast_scalar(nsize, master_task)
               if (my_task == master_task) then
                  if (nsize <= len(work_line)) then
                     iostat = nf90_get_att(ncid, io_field%id, &
                                           trim(att_name), &
                                           work_line(1:nsize))
                  else
                     call document('define_field_netcdf', 'nsize', nsize)
                     call document('define_field_netcdf', 'len(work_line)', &
                                   len(work_line))
                     write(stdout,*) 'string too short; not enough room to read ' /&
                                     &/ trim(att_name) /&
                                     &/ ' of ' /&
                                     &/ trim(io_field%short_name) /&
                                     &/ ' from ' /&
                                     &/ trim(data_file%full_name)
                  endif
               endif
               call broadcast_scalar(iostat, master_task)
               if (iostat /= nf90_noerr) then
                  call exit_POP(sigAbort, &
                                'Error reading netCDF file attribute')
               endif

               call broadcast_scalar(work_line, master_task)
               call add_attrib_io_field(io_field, trim(att_name), &
                                                  trim(work_line))

            case (NF90_INT) !*** both integer and logical attributes
               if (my_task == master_task) then
                  iostat = nf90_get_att(ncid, io_field%id, &
                                        trim(att_name), att_ival)
               endif
               call broadcast_scalar(iostat, master_task)
               if (iostat /= nf90_noerr) then
                  call exit_POP(sigAbort, &
                                'Error reading netCDF file attribute')
               endif

               call broadcast_scalar(att_ival, master_task)
               if (att_name(1:4) == 'LOG_') then !*** attribute logical
                  work_line = att_name
                  work_line(1:4) = '    '
                  att_name = adjustl(work_line)

                  if (att_ival == 1) then
                     att_lval = .true.
                  else
                     att_lval = .false.
                  endif
                  call add_attrib_file(data_file, trim(att_name), &
                                                  att_lval)

               else
                  call add_attrib_file(data_file, trim(att_name), &
                                                  att_ival)
               endif

            case (NF90_FLOAT)
               if (my_task == master_task) then
                  iostat = nf90_get_att(ncid, io_field%id, &
                                        trim(att_name), att_rval)
               endif
               call broadcast_scalar(iostat, master_task)
               if (iostat /= nf90_noerr) then
                  call exit_POP(sigAbort, &
                                'Error reading netCDF file attribute')
               endif

               call broadcast_scalar(att_rval, master_task)
               call add_attrib_io_field(io_field, trim(att_name), &
                                                  att_rval)

            case (NF90_DOUBLE)
               if (my_task == master_task) then
                  iostat = nf90_get_att(ncid, io_field%id, &
                                        trim(att_name), att_dval)
               endif
               call broadcast_scalar(iostat, master_task)
               if (iostat /= nf90_noerr) then
                  call exit_POP(sigAbort, &
                                'Error reading netCDF file attribute')
               endif

               call broadcast_scalar(att_dval, master_task)
               call add_attrib_io_field(io_field, trim(att_name), &
                                                  att_dval)

            end select

         end select

      end do ! num_atts

!-----------------------------------------------------------------------
!
! for output files, need to define everything
! make sure file is in define mode
!
!-----------------------------------------------------------------------

   else ! output file

      if (.not. data_file%ldefine) &
        call exit_POP(sigAbort, &
                      'attempt to define field but not in define mode')

!-----------------------------------------------------------------------
!
! define the dimensions
!
!-----------------------------------------------------------------------

      ndims = io_field%nfield_dims

      if (my_task == master_task) then
         do n = 1,ndims
            dimid = 0

            !*** check to see whether already defined

            iostat = NF90_INQ_DIMID(ncid=ncid, &
                                 name=trim(io_field%field_dim(n)%name),&
                                 dimid=dimid)

            if (iostat /= NF90_NOERR) then ! dimension not yet defined
               iostat = NF90_DEF_DIM (ncid=ncid, &
                             name=trim(io_field%field_dim(n)%name), &
                             len=io_field%field_dim(n)%length, &
                             dimid=io_field%field_dim(n)%id)
            else
               io_field%field_dim(n)%id = dimid
            end if
         end do

!-----------------------------------------------------------------------
!
! now define the field
!
!-----------------------------------------------------------------------

         !*** check to see whether field of this name already defined.

         iostat = NF90_INQ_VARID(ncid, trim(io_field%short_name), varid)

         if (iostat /= NF90_NOERR) then ! variable was not yet defined

                 if (associated (io_field%field_r_1d).or. &
                     associated (io_field%field_r_2d).or. &
                     associated (io_field%field_r_3d)) then
               iostat = NF90_DEF_VAR (ncid=ncid, &
                                      name=trim(io_field%short_name), &
                                      xtype=NF90_FLOAT, &
                    dimids=(/ (io_field%field_dim(n)%id, n=1,ndims) /),&
                                      varid=io_field%id)

            else if ( io_field%nfield_dims == c0) then
               ! do not supply optional dimids for scalars
               iostat = NF90_DEF_VAR (ncid=ncid, &
                                      name=trim(io_field%short_name), &
                                      xtype=NF90_DOUBLE, &
                                      varid=io_field%id)
            else if (associated (io_field%field_d_1d).or. &
                     associated (io_field%field_d_2d).or. &
                     associated (io_field%field_d_3d)) then
               iostat = NF90_DEF_VAR (ncid=ncid, &
                                      name=trim(io_field%short_name), &
                                      xtype=NF90_DOUBLE, &
                   dimids=(/ (io_field%field_dim(n)%id, n=1,ndims) /),&
                                      varid=io_field%id)
            else if (associated (io_field%field_i_1d).or. &
                     associated (io_field%field_i_2d).or. &
                     associated (io_field%field_i_3d)) then
               iostat = NF90_DEF_VAR (ncid=ncid, &
                                      name=trim(io_field%short_name), &
                                      xtype=NF90_INT, &
                   dimids=(/ (io_field%field_dim(n)%id, n=1,ndims) /),&
                                      varid=io_field%id)
            else
               define_error = .true.
            end if
            call check_status(iostat)
            if (iostat /= nf90_noerr) define_error = .true.
     varid = io_field%id
         else ! Variable was previously defined, OK to use it
            io_field%id = varid
         end if
      end if ! master task

      call broadcast_scalar(define_error, master_task)
      if (define_error) then
        write(stdout,*) '(define_field_netcdf) ', trim(io_field%short_name)
        call exit_POP(sigAbort, 'Error defining netCDF field')
      endif

!-----------------------------------------------------------------------
!
! Now define the field attributes
!
!-----------------------------------------------------------------------

      if (my_task == master_task) then

         !*** long_name

         if (io_field%long_name /= char_blank) then
            iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=varid, &
                                            name='long_name')
            if (iostat /= NF90_NOERR) then ! attrib probably not defined
               iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                                     name='long_name', &
                                     values=trim(io_field%long_name))
               call check_status(iostat)
               if (iostat /= NF90_NOERR) define_error = .true.
            end if
         endif

         !*** units

         if (io_field%units /= char_blank) then
            iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=varid, &
                                            name='units')
            if (iostat /= NF90_NOERR) then ! attrib probably not defined
               iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                                     name='units', &
                                     values=trim(io_field%units))
               call check_status(iostat)
               if (iostat /= NF90_NOERR) define_error = .true.
            end if
         endif

         !*** coordinates

         if (io_field%coordinates /= char_blank) then
            iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=varid, &
                                            name='coordinates')
            if (iostat /= NF90_NOERR) then ! attrib probably not defined
               iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                                     name='coordinates', &
                                     values=trim(io_field%coordinates))
               call check_status(iostat)
               if (iostat /= NF90_NOERR) define_error = .true.
            end if
         endif

         !*** grid_loc

         if (io_field%grid_loc /= '    ') then
            iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=varid, &
                                            name='grid_loc')
            if (iostat /= NF90_NOERR) then ! attrib probably not defined
               iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                                     name='grid_loc', &
                                     values=io_field%grid_loc)
               call check_status(iostat)
               if (iostat /= NF90_NOERR) define_error = .true.
            end if
         endif


         !*** missing_value

         if (io_field%missing_value /= undefined) then
            iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=varid, &
                                            name='missing_value')
            if (iostat /= NF90_NOERR) then ! attrib probably not defined
               iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                                     name='missing_value', &
                                     values=io_field%missing_value)
               call check_status(iostat)
               if (iostat /= NF90_NOERR) define_error = .true.
            end if
         endif

         !*** missing_value_i

         if (io_field%missing_value_i == undefined_nf_int) then
            iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=varid, &
                                            name='missing_value')
            if (iostat /= NF90_NOERR) then ! attrib probably not defined
               iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                                     name='missing_value', &
                                     values=io_field%missing_value_i)
               call check_status(iostat)
               if (iostat /= NF90_NOERR) define_error = .true.
            end if
         endif



         !*** valid_range(1:2)

         if (any(io_field%valid_range /= undefined)) then
            iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=varid, &
                                            name='valid_range')
            if (iostat /= NF90_NOERR) then ! attrib probably not yet defined
               iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                                     name='valid_range', &
                                     values=io_field%valid_range(:))
               call check_status(iostat)
               if (iostat /= NF90_NOERR) define_error = .true.
            end if
         endif

         !*** additional attributes if defined

         ncvals = 0
         nlvals = 0
         nivals = 0
         nrvals = 0
         ndvals = 0
         if (associated(io_field%add_attrib_cval)) &
            ncvals = size(io_field%add_attrib_cval)
         if (associated(io_field%add_attrib_lval)) &
            nlvals = size(io_field%add_attrib_lval)
         if (associated(io_field%add_attrib_ival)) &
            nivals = size(io_field%add_attrib_ival)
         if (associated(io_field%add_attrib_rval)) &
            nrvals = size(io_field%add_attrib_rval)
         if (associated(io_field%add_attrib_dval)) &
            ndvals = size(io_field%add_attrib_dval)

         do n=1,ncvals
            iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                         name=trim(io_field%add_attrib_cname(n)), &
                         values=trim(io_field%add_attrib_cval(n)))
            call check_status(iostat)
            if (iostat /= NF90_NOERR) define_error = .true.
         end do

         do n=1,nlvals
            work_line = 'LOG_'/&
                               &/trim(io_field%add_attrib_lname(n))
            iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                         name=trim(work_line), &
                         values=io_field%add_attrib_ival(n))
            call check_status(iostat)
            if (iostat /= NF90_NOERR) define_error = .true.
         end do

         do n=1,nivals
            iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                         name=trim(io_field%add_attrib_iname(n)), &
                         values=io_field%add_attrib_ival(n))
            call check_status(iostat)
            if (iostat /= NF90_NOERR) define_error = .true.
         end do

         do n=1,nrvals
            iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                         name=trim(io_field%add_attrib_rname(n)), &
                         values=io_field%add_attrib_rval(n))
            call check_status(iostat)
            if (iostat /= NF90_NOERR) define_error = .true.
         end do

         do n=1,ndvals
            iostat = NF90_PUT_ATT(ncid=NCID, varid=varid, &
                         name=trim(io_field%add_attrib_dname(n)), &
                         values=io_field%add_attrib_dval(n))
            call check_status(iostat)
            if (iostat /= NF90_NOERR) define_error = .true.
         end do

      endif ! master_task

      call broadcast_scalar(define_error, master_task)
      if (define_error) call exit_POP(sigAbort, &
                        'Error adding attributes to field')

   endif ! input/output file

!-----------------------------------------------------------------------
!EOC

 end subroutine define_field_netcdf

!***********************************************************************
!BOP
! !IROUTINE: write_field_netcdf
! !INTERFACE:

 subroutine write_field_netcdf(data_file, io_field)

! !DESCRIPTION:
! This routine writes a field to a netCDF data file.
!
! !REVISION HISTORY:
! same as module

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (inout) :: &
      data_file ! file to which field will be written

   type (io_field_desc), intent (inout) :: &
      io_field ! field to write to file

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   integer (i4), dimension(:,:), allocatable :: global_i_2d
   real (r4), dimension(:,:), allocatable :: global_r_2d
   real (r8), dimension(:,:), allocatable :: global_d_2d

   integer (i4), dimension(:), allocatable :: &
      start,length ! dimension quantities for netCDF

   integer (i4) :: &
      iostat, &! netCDF status flag
      k,n ! loop counters

   logical (log_kind) :: &
      write_error ! error flag

!-----------------------------------------------------------------------
!
! exit define mode if necessary
!
!-----------------------------------------------------------------------

   write_error = .false.

   if (my_task == master_task) then
      if (data_file%ldefine) then
         iostat = nf90_enddef(data_file%id(1))
         data_file%ldefine = .false.
         call check_status(iostat)
         if (iostat /= nf90_noerr) write_error = .true.
      endif
   endif

   call broadcast_scalar(write_error, master_task)
   if (write_error) then
      write(stdout,*) '(write_field_netcdf) filename = ', &
                        trim(data_file%full_name)
      call exit_POP(sigAbort, &
                    'Error exiting define mode in netCDF write')
   endif

!-----------------------------------------------------------------------
!
! make sure field has been defined
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then
      if (io_field%id == 0) write_error = .true.
   endif

   call broadcast_scalar(write_error, master_task)
   if (write_error) &
      call exit_POP(sigAbort, &
                    'Attempt to write undefined field in netCDF write')

!-----------------------------------------------------------------------
!
! allocate dimension start,stop quantities
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then

      if (associated(io_field%field_r_3d) .or. &
          associated(io_field%field_d_3d) .or. &
          associated(io_field%field_i_3d) ) then
             allocate(start(3), length(3) )
      endif

!-----------------------------------------------------------------------
!
! allocate global arrays - these are for 2-d slices of data which
! are gathered to the master task
!
!-----------------------------------------------------------------------

      if (associated(io_field%field_r_3d) .or. &
          associated(io_field%field_r_2d)) then
         allocate(global_r_2d(nx_global,ny_global))
      else if (associated(io_field%field_d_3d) .or. &
               associated(io_field%field_d_2d)) then
         allocate(global_d_2d(nx_global,ny_global))
      else if (associated(io_field%field_i_3d) .or. &
               associated(io_field%field_i_2d)) then
         allocate(global_i_2d(nx_global,ny_global))
      endif

   endif ! master task

!-----------------------------------------------------------------------
!
! write data based on type
!
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!
! real 3d array
!
!-----------------------------------------------------------------------

   if (associated(io_field%field_r_3d)) then

!!! do k = 1,size(io_field%field_r_3d,dim=3)
      do k = 1,io_field%field_dim(3)%length
         call gather_global(global_r_2d, io_field%field_r_3d(:,:,k,:), &
                            master_task, distrb_clinic)
         if (my_task == master_task) then

            !*** tell netCDF to only write slice n
            io_field%field_dim(3)%start = k
            io_field%field_dim(3)%stop = k

            do n=1,3
               start (n) = io_field%field_dim(n)%start
               length(n) = io_field%field_dim(n)%stop - start(n) + 1
            end do
            iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                   varid=io_field%id, &
                                   values=global_r_2d, &
                                   start=start(:), count=length(:))
            if (iostat /= nf90_noerr) then
               call check_status(iostat)
               write_error = .true.
            endif
         endif ! master task
      end do ! slice loop

!-----------------------------------------------------------------------
!
! real 2d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_r_2d)) then

      call gather_global(global_r_2d, io_field%field_r_2d, &
                         master_task, distrb_clinic)
      if (my_task == master_task) then

         iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=global_r_2d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            write_error = .true.
         endif
      endif ! master task

!-----------------------------------------------------------------------
!
! real 1d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_r_1d)) then

      if (my_task == master_task) then
         ! 1d vectors are not distributed to blocks; no need for gather_global
         iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_r_1d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            write_error = .true.
         endif
      endif ! master task

!-----------------------------------------------------------------------
!
! real 0d array
!
!-----------------------------------------------------------------------
! deferred

!-----------------------------------------------------------------------
!
! double 3d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_d_3d)) then

!!! do k = 1,size(io_field%field_d_3d,dim=3)
      do k = 1,io_field%field_dim(3)%length
         call gather_global(global_d_2d, io_field%field_d_3d(:,:,k,:), &
                            master_task, distrb_clinic)
         if (my_task == master_task) then

            !*** tell netCDF to only write slice n
            io_field%field_dim(3)%start = k
            io_field%field_dim(3)%stop = k

            do n=1,3
               start (n) = io_field%field_dim(n)%start
               length(n) = io_field%field_dim(n)%stop - start(n) + 1
            end do

            iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                   varid=io_field%id, &
                                   values=global_d_2d, &
                                   start=start(:), count=length(:))
            if (iostat /= nf90_noerr) then
               call check_status(iostat)
               write_error = .true.
            endif
         endif ! master task
      end do ! slice loop

!-----------------------------------------------------------------------
!
! double 2d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_d_2d)) then

      call gather_global(global_d_2d, io_field%field_d_2d, &
                         master_task, distrb_clinic)
      if (my_task == master_task) then

         iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=global_d_2d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            write_error = .true.
         endif
      endif ! master task

!-----------------------------------------------------------------------
!
! double 1d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_d_1d)) then

      if (my_task == master_task) then
         ! 1d vectors are not distributed to blocks; no need for gather_global
         iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_d_1d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            write_error = .true.
         endif
      endif ! master task

!-----------------------------------------------------------------------
!
! double 0d array
!
!-----------------------------------------------------------------------

   else if ( io_field%nfield_dims == c0) then

      if (my_task == master_task) then
         ! scalars are not distributed to blocks; no need for gather_global
         ! for now, all scalars are r8 and are not pointers or targets
         iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_d_0d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            write_error = .true.
         endif
      endif ! master task


!-----------------------------------------------------------------------
!
! integer 3d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_i_3d)) then

!!! do k = 1,size(io_field%field_i_3d,dim=3)
      do k = 1,io_field%field_dim(3)%length
         call gather_global(global_i_2d, io_field%field_i_3d(:,:,k,:), &
                            master_task, distrb_clinic)
         if (my_task == master_task) then

            !*** tell netCDF to only write slice n
            io_field%field_dim(3)%start = k
            io_field%field_dim(3)%stop = k

            do n=1,io_field%nfield_dims
               start (n) = io_field%field_dim(n)%start
               length(n) = io_field%field_dim(n)%stop - start(n) + 1
            end do

            iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                   varid=io_field%id, &
                                   values=global_i_2d, &
                                   start=start(:), count=length(:))
            if (iostat /= nf90_noerr) then
               call check_status(iostat)
               write_error = .true.
            endif
         endif ! master task
      end do ! slice loop

!-----------------------------------------------------------------------
!
! integer 2d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_i_2d)) then

      call gather_global(global_i_2d, io_field%field_i_2d, &
                         master_task, distrb_clinic)
      if (my_task == master_task) then

         iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=global_i_2d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            write_error = .true.
         endif
      endif ! master task


!-----------------------------------------------------------------------
!
! integer 1d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_i_1d)) then

      if (my_task == master_task) then
         ! 1d vectors are not distributed to blocks; no need for gather_global
         iostat = NF90_PUT_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_i_1d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            write_error = .true.
         endif
      endif ! master task

!-----------------------------------------------------------------------
!
! check for write errors
!
!-----------------------------------------------------------------------

   else
      call exit_POP(sigAbort, &
                    'No field associated for writing to netCDF')
   end if

   call broadcast_scalar(write_error, master_task)
   if (write_error) then
      call document('write_field_netcdf', 'short_name', io_field%short_name)
      call exit_POP(sigAbort, &
                    'Error writing field to netCDF file')
   endif

!-----------------------------------------------------------------------
!
! deallocate quantities
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then
      if (allocated(start)) deallocate(start)
      if (allocated(length)) deallocate(length)
      if (allocated(global_r_2d)) deallocate(global_r_2d)
      if (allocated(global_d_2d)) deallocate(global_d_2d)
      if (allocated(global_i_2d)) deallocate(global_i_2d)
   endif

!-----------------------------------------------------------------------
!EOC

 end subroutine write_field_netcdf

!***********************************************************************
!BOP
! !IROUTINE: read_field_netcdf
! !INTERFACE:

 subroutine read_field_netcdf(data_file, io_field)

! !DESCRIPTION:
! This routine reads a field from a netcdf input file.
!
! !REVISION HISTORY:
! same as module

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (inout) :: &
      data_file ! file from which to read field

   type (io_field_desc), intent (inout) :: &
      io_field ! field to be read

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   integer (i4), dimension(:,:), allocatable :: global_i_2d
   real (r4), dimension(:,:), allocatable :: global_r_2d
   real (r8), dimension(:,:), allocatable :: global_d_2d

   integer (i4), dimension(:), allocatable :: &
      start,length ! dimension quantities for netCDF

   integer (i4) :: &
      iostat, &! netCDF status flag
      k,n ! loop counters

   logical (log_kind) :: &
      read_error ! error flag

!-----------------------------------------------------------------------
!
! make sure field has been defined
!
!-----------------------------------------------------------------------


   read_error = .false.
   if (my_task == master_task) then
      if (io_field%id == 0) read_error = .true.
   endif

   call broadcast_scalar(read_error, master_task)
   if (read_error) &
      call exit_POP(sigAbort, &
                    'Attempt to read undefined field in netCDF read')

!-----------------------------------------------------------------------
!
! if no boundary update type defined, assume center location scalar
!
!-----------------------------------------------------------------------

   if (io_field%field_loc == field_loc_unknown) then
      io_field%field_loc = field_loc_center
      io_field%field_type = field_type_scalar
   endif

!-----------------------------------------------------------------------
!
! allocate dimension start,stop quantities
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then
      if (associated(io_field%field_r_3d) .or. &
          associated(io_field%field_d_3d) .or. &
          associated(io_field%field_i_3d) ) then
             allocate(start(3), length(3) )
      endif
!-----------------------------------------------------------------------
!
! allocate global arrays - these are for 2-d slices of data which
! are gathered to the master task
!
!-----------------------------------------------------------------------

      if (associated(io_field%field_r_3d) .or. &
          associated(io_field%field_r_2d)) then
         allocate(global_r_2d(nx_global,ny_global))
      else if (associated(io_field%field_d_3d) .or. &
               associated(io_field%field_d_2d)) then
         allocate(global_d_2d(nx_global,ny_global))
      else if (associated(io_field%field_i_3d) .or. &
               associated(io_field%field_i_2d)) then
         allocate(global_i_2d(nx_global,ny_global))
      endif

   endif ! master task

!-----------------------------------------------------------------------
!
! read data based on type
!
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!
! real 3d array
!
!-----------------------------------------------------------------------

   if (associated(io_field%field_r_3d)) then

!!! do k = 1,size(io_field%field_r_3d,dim=3)
      do k = 1,io_field%field_dim(3)%length
         if (my_task == master_task) then

            !*** tell netCDF to only read slice n
            io_field%field_dim(3)%start = k
            io_field%field_dim(3)%stop = k

            do n=1,io_field%nfield_dims
               start (n) = io_field%field_dim(n)%start
               length(n) = io_field%field_dim(n)%stop - start(n) + 1
            end do

            iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                   varid=io_field%id, &
                                   values=global_r_2d, &
                                   start=start(:), count=length(:))
            if (iostat /= nf90_noerr) then
               call check_status(iostat)
               read_error = .true.
            endif
         endif ! master task

         call broadcast_scalar(read_error, master_task)
         if (.not. read_error) &
            call scatter_global(io_field%field_r_3d(:,:,k,:), &
                                global_r_2d, master_task, distrb_clinic, &
                                io_field%field_loc, io_field%field_type)

      end do ! slice loop

!-----------------------------------------------------------------------
!
! real 2d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_r_2d)) then

      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=global_r_2d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)
      if (.not. read_error) then
         call scatter_global(io_field%field_r_2d, &
                             global_r_2d, master_task, distrb_clinic, &
                             io_field%field_loc, io_field%field_type)
      endif

!-----------------------------------------------------------------------
!
! real 1d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_r_1d)) then

      ! 1d vectors are not distributed to blocks; therefore, no scatter_global needed
      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_r_1d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)

!-----------------------------------------------------------------------
!
! real 0d array (scalar)
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_r_1d)) then

      ! scalars are not distributed to blocks; therefore, no scatter_global needed
      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_r_0d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)


!-----------------------------------------------------------------------
!
! double 3d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_d_3d)) then

!!! do k = 1,size(io_field%field_d_3d,dim=3)
      do k = 1,io_field%field_dim(3)%length
         if (my_task == master_task) then

            !*** tell netCDF to only read slice n
            io_field%field_dim(3)%start = k
            io_field%field_dim(3)%stop = k

            do n=1,io_field%nfield_dims
               start (n) = io_field%field_dim(n)%start
               length(n) = io_field%field_dim(n)%stop - start(n) + 1
            end do

            iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                   varid=io_field%id, &
                                   values=global_d_2d, &
                                   start=start(:), count=length(:))
            if (iostat /= nf90_noerr) then
               call check_status(iostat)
               read_error = .true.
            endif
         endif ! master task

         call broadcast_scalar(read_error, master_task)
         if (.not. read_error) &
            call scatter_global(io_field%field_d_3d(:,:,k,:), &
                                global_d_2d, master_task, distrb_clinic, &
                                io_field%field_loc, io_field%field_type)

      end do ! slice loop

!-----------------------------------------------------------------------
!
! double 2d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_d_2d)) then

      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=global_d_2d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)
      if (.not. read_error) then
         call scatter_global(io_field%field_d_2d, &
                             global_d_2d, master_task, distrb_clinic, &
                             io_field%field_loc, io_field%field_type)
      endif

!-----------------------------------------------------------------------
!
! double 1d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_d_1d)) then

      ! 1d vectors are not distributed to blocks; therefore, no scatter_global needed
      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_d_1d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)

!-----------------------------------------------------------------------
!
! double 0d array (scalar)
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_d_1d)) then

      ! scalars are not distributed to blocks; therefore, no scatter_global needed
      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_d_0d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)

!-----------------------------------------------------------------------
!
! integer 3d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_i_3d)) then

!!! do k = 1,size(io_field%field_i_3d,dim=3)
      do k = 1,io_field%field_dim(3)%length
         if (my_task == master_task) then

            !*** tell netCDF to only read slice n
            io_field%field_dim(3)%start = k
            io_field%field_dim(3)%stop = k

            do n=1,io_field%nfield_dims
               start (n) = io_field%field_dim(n)%start
               length(n) = io_field%field_dim(n)%stop - start(n) + 1
            end do

            iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                   varid=io_field%id, &
                                   values=global_i_2d, &
                                   start=start(:), count=length(:))
            if (iostat /= nf90_noerr) then
               call check_status(iostat)
               read_error = .true.
            endif
         endif ! master task

         call broadcast_scalar(read_error, master_task)
         if (.not. read_error) &
            call scatter_global(io_field%field_i_3d(:,:,k,:), &
                                global_i_2d, master_task, distrb_clinic, &
                                io_field%field_loc, io_field%field_type)

      end do ! slice loop

!-----------------------------------------------------------------------
!
! integer 2d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_i_2d)) then

      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=global_i_2d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)
      if (.not. read_error) then
         call scatter_global(io_field%field_i_2d, &
                             global_i_2d, master_task, distrb_clinic, &
                             io_field%field_loc, io_field%field_type)
      endif

!-----------------------------------------------------------------------
!
! integer 1d array
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_i_1d)) then

      ! 1d vectors are not distributed to blocks; therefore, no scatter_global needed
      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_i_1d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)

!-----------------------------------------------------------------------
!
! integer 0d array (scalar)
!
!-----------------------------------------------------------------------

   else if (associated(io_field%field_i_1d)) then

      ! scalars are not distributed to blocks; therefore, no scatter_global needed
      if (my_task == master_task) then

         iostat = NF90_GET_VAR (ncid=data_file%id(1), &
                                varid=io_field%id, &
                                values=io_field%field_i_0d)
         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            read_error = .true.
         endif
      endif ! master task

      call broadcast_scalar(read_error, master_task)

!-----------------------------------------------------------------------
!
! check for read errors
!
!-----------------------------------------------------------------------

   else
      call exit_POP(sigAbort, &
                    'No field associated for reading from netCDF')
   end if

   call broadcast_scalar(read_error, master_task)
   if (read_error) &
      call exit_POP(sigAbort,'Error reading field from netCDF file')

!-----------------------------------------------------------------------
!
! deallocate quantities
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then
      if (allocated(start)) deallocate(start)
      if (allocated(length)) deallocate(length)
      if (allocated(global_r_2d)) deallocate(global_r_2d)
      if (allocated(global_d_2d)) deallocate(global_d_2d)
      if (allocated(global_i_2d)) deallocate(global_i_2d)
   endif


!-----------------------------------------------------------------------
!EOC

 end subroutine read_field_netcdf

!***********************************************************************
!BOP
! !IROUTINE: check_status
! !INTERFACE:

 subroutine check_status(status)

! !DESCRIPTION:
! This exception handler subroutine can be used to check error status
! after a netcdf call. It prints out a text message assigned to
! an error code but does not exit because this routine is typically
! only called from a single process.
!
! !REVISION HISTORY:
! same as module

! !INPUT PARAMETERS:

   integer (i4), intent (in) :: &
      status ! status returned by netCDF call

!EOP
!BOC
!-----------------------------------------------------------------------
!
! call netCDF routine to return error message
!
!-----------------------------------------------------------------------

   if (status /= nf90_noerr) then
      write(stdout,*) trim(nf90_strerror(status))
      call POP_IOUnitsFlush(POP_stdout) ; call POP_IOUnitsFlush(stdout)
   end if

!-----------------------------------------------------------------------
!EOC

 end subroutine check_status

!***********************************************************************
!BOP
! !IROUTINE: define_nstd_netcdf
! !INTERFACE:

 subroutine define_nstd_netcdf(data_file,ndims,io_dims,field_id, &
                                 short_name,long_name,units,coordinates, &
                                 fill_value,missing_value,nftype)

! !DESCRIPTION:
! This routine defines the nonstandard CCSM time-averaged diagnostic fields
! on nonstandard grids: MOC, N_HEAT, and N_SALT
! This routine is totally CCSM-specific
!
!
! !REVISION HISTORY:
! same as module

! !INPUT PARAMETERS:

   type (datafile), intent (in) :: &
      data_file ! data file in which field contained

   real (rtavg), intent (in) :: &
      fill_value, &
      missing_value

   integer (int_kind), intent(in) :: &
      ndims ! number of dimensions for nonstandard field

   character (*), intent (in) :: &
      short_name, &
      long_name, &
      units, &
      coordinates, &
      nftype

! !INPUT/OUTPUT PARAMETERS:

   type (io_dim), dimension(:), intent (inout) :: &
      io_dims

   integer (i4), intent (inout) :: &
      field_id ! variable id

   optional :: coordinates,fill_value,missing_value,nftype

!EOP
!BOP
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   integer (i4) :: &
      iostat, &! status flag for netCDF calls
      ncid, &! file id for netcdf file
      n, &! loop index
      xtype

   logical (log_kind) :: &
      define_error ! error flag

   define_error = .false.
   ncid = data_file%id(1)

!-----------------------------------------------------------------------
!
! make sure file has been opened and is in define mode
!
!-----------------------------------------------------------------------

   call check_file_open (data_file, 'define_nstd_netcdf')
   call check_definemode (data_file, 'define_nstd_netcdf')


!-----------------------------------------------------------------------
!
! define the dimensions
!
!-----------------------------------------------------------------------

   call define_dimensions(data_file,ndims,io_dims)

!-----------------------------------------------------------------------
!
! define the field
!
!-----------------------------------------------------------------------

   if (present(nftype)) then
      select case (trim(nftype))
        case ('float','FLOAT')
          xtype = NF90_FLOAT
        case ('double','DOUBLE')
          xtype = NF90_DOUBLE
        case ('integer','INTEGER')
          xtype = NF90_INT
        case ('char','CHAR','character', 'CHARACTER')
          xtype = NF90_CHAR
        case default
          call exit_POP(sigAbort,'unknown nftype')
      end select
   else
    xtype = NF90_FLOAT
   endif

   call define_var (data_file,trim(short_name),ndims,io_dims, &
                    xtype,field_id)

!-----------------------------------------------------------------------
!
! Now define the field attributes
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then

      !*** long_name
       iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=field_id, &
                                       name='long_name')
       if (iostat /= NF90_NOERR) then ! attrib probably not defined
          iostat = NF90_PUT_ATT(ncid=NCID, varid=field_id, &
                                name='long_name', &
                                values=trim(long_name))
          call check_status(iostat)
          if (iostat /= NF90_NOERR) define_error = .true.
       end if

      !*** units
       iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=field_id, &
                                       name='units')
       if (iostat /= NF90_NOERR) then ! attrib probably not defined
          iostat = NF90_PUT_ATT(ncid=NCID, varid=field_id, &
                                name='units', &
                                values=trim(units))
          call check_status(iostat)
          if (iostat /= NF90_NOERR) define_error = .true.
       end if

      !*** coordinates
       if (present(coordinates)) then
          iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=field_id, &
                                          name='coordinates')
          if (iostat /= NF90_NOERR) then ! attrib probably not defined
             iostat = NF90_PUT_ATT(ncid=NCID, varid=field_id, &
                                   name='coordinates', &
                                   values=trim(coordinates))
             call check_status(iostat)
             if (iostat /= NF90_NOERR) define_error = .true.
          end if
       endif

      !*** missing_value
       if (present(missing_value)) then
          iostat = NF90_INQUIRE_ATTRIBUTE(ncid=NCID, varid=field_id, &
                                          name='missing_value')
          if (iostat /= NF90_NOERR) then ! attrib probably not defined
             iostat = NF90_PUT_ATT(ncid=NCID, varid=field_id, &
                                   name='missing_value', &
                                   values=missing_value)
             call check_status(iostat)
             if (iostat /= NF90_NOERR) define_error = .true.
          end if
       endif

   endif ! master_task

   call broadcast_scalar(define_error, master_task)
   if (define_error) call exit_POP(sigAbort, &
                     '(define_nstd_netcdf) Error adding attributes to field')


!-----------------------------------------------------------------------
!EOC

 end subroutine define_nstd_netcdf

!***********************************************************************
!BOP
! !IROUTINE: write_nstd_netcdf
! !INTERFACE:

 subroutine write_nstd_netcdf(data_file,field_id,num_writes, &
                              ndims, io_dims, &
                              nftype, &
                              implied_time_dim, &
                              indata_1d_r8, &
                              indata_2d_r8, &
                              indata_2d_r4, &
                              indata_3d_r4 , &
                              indata_4d_r4, &
                              indata_1d_ch, &
                              indata_2d_ch )

! !DESCRIPTION:
! This is a specialized, CCSM-speicific routine to write any desired
! output field that cannot presently be defined through construct_io_field
! to the CCSM version of the netCDF time-averaged history output files
!
! !REVISION HISTORY:
! same as module


! !INPUT PARAMETERS:

   character (*), intent (in) :: &
       nftype

   integer (i4), intent (in) :: &
      field_id ! netCDF id for the nonstandard variables

   integer (int_kind), intent (in) :: &
      num_writes, &
      ndims

   type (io_dim), dimension(:), intent (in) :: &
      io_dims

   real (r8), dimension(:,:),intent (in) :: &
      indata_2d_r8
   real (r8), dimension(:), intent (in) :: &
      indata_1d_r8

   real (r4), dimension(:,:,:,:), intent (in) :: &
      indata_4d_r4
   real (r4), dimension(:,:,:), intent (in) :: &
      indata_3d_r4
   real (r4), dimension(:,:), intent (in) :: &
      indata_2d_r4

   character (*), dimension(:,:), intent (in) :: &
      indata_2d_ch
   character (*), dimension(:), intent (in) :: &
      indata_1d_ch

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (inout) :: &
      data_file ! file to which field will be written

   logical (log_kind), intent(inout) :: &
      implied_time_dim

   optional :: &
     implied_time_dim, &
     indata_1d_r8, &
     indata_2d_r8, &
     indata_2d_r4, &
     indata_3d_r4, &
     indata_4d_r4, &
     indata_1d_ch, &
     indata_2d_ch

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   integer , dimension(2) :: &
      start,count ! dimension quantities for netCDF

   integer :: &
      iostat, &! netCDF status flag
      n ! index

   integer :: ncid, nout(5)

   logical (log_kind) :: &
      write_error, &! error flag
      supported

   real (r4), allocatable, dimension (:,:,:,:,:) :: &
      outdata_5d_r4

   real (r4), allocatable, dimension (:,:,:,:) :: &
      outdata_4d_r4

   real (r4), allocatable, dimension (:,:,:) :: &
      outdata_3d_r4

   real (r4), allocatable, dimension (:,:) :: &
      outdata_2d_r4

   real (r8), allocatable, dimension (:) :: &
      outdata_1d_r8
   real (r8), allocatable, dimension (:,:) :: &
      outdata_2d_r8

   character(char_len), allocatable, dimension (:,:) :: &
      outdata_2d_ch

!-----------------------------------------------------------------------
!
! exit define mode if necessary
!
!-----------------------------------------------------------------------


   write_error = .false.

   if (my_task == master_task) then
      if (data_file%ldefine) then
         iostat = nf90_enddef(data_file%id(1))
         data_file%ldefine = .false.
         call check_status(iostat)
         if (iostat /= nf90_noerr) write_error = .true.
      endif
   endif

   call broadcast_scalar(write_error, master_task)
   if (write_error) then
      write(stdout,*) '(write_nstd_netcdf) filename = ', &
                        trim(data_file%full_name)
      call exit_POP(sigAbort, &
          '(write_nstd_netcdf) Error exiting define mode in netCDF write')
   endif

!-----------------------------------------------------------------------
!
! make sure field has been defined
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then
      if (field_id == 0) write_error = .true.
   endif

   call broadcast_scalar(write_error, master_task)
   if (write_error) &
      call exit_POP(sigAbort, &
          '(write_nstd_netcdf) Attempt to write undefined field in netCDF write')

!-----------------------------------------------------------------------
!
! determine if the variable has the unlimited time dimension
! as an implicit dimension; if so, it must be made explicit
! in the outdata array
!
!-----------------------------------------------------------------------

   if (.not. present(implied_time_dim)) then
     implied_time_dim = .false.
   endif


!-----------------------------------------------------------------------
! NOTE: this version does not yet support multiple writes to the same
! netCDF file, but neither does basic pop2...
!-----------------------------------------------------------------------

      supported = .true.

      if (my_task == master_task) then

         ncid = data_file%id(1)

         select case (trim(nftype))

           case('double','DOUBLE')
              select case (implied_time_dim)
                case (.true.)
                   select case (ndims)
                       case(2)
                          nout(1) = size(indata_1d_r8,DIM=1)
                          allocate (outdata_2d_r8(nout(1),1))
                          outdata_2d_r8(:,1) = indata_1d_r8(:)
                          iostat = NF90_PUT_VAR (ncid, field_id, outdata_2d_r8 )
                          deallocate (outdata_2d_r8)
                       case default
                        supported = .false.
                   end select ! ndims
                case (.false.)
                   select case (ndims)
                       case(1)
                          iostat = NF90_PUT_VAR (ncid, field_id, indata_1d_r8 )
                       case(2)
                          iostat = NF90_PUT_VAR (ncid, field_id, indata_2d_r8 )
                       case default
                        supported = .false.
                   end select ! ndims
              end select ! implied_time_dim

           case('float','FLOAT')
              select case (implied_time_dim)
                case (.true.)
                   select case (ndims)
                       case(1)
                          supported = .false.
                       case(2)
                          supported = .false.
                       case(3)
                          nout(1) = size(indata_3d_r4,DIM=1)
                          nout(2) = size(indata_3d_r4,DIM=2)
                          allocate (outdata_3d_r4(nout(1),nout(2),1))
                          outdata_3d_r4(:,:,1) = indata_2d_r4(:,:)
                          iostat = NF90_PUT_VAR (ncid, field_id, outdata_3d_r4 )
                          deallocate (outdata_3d_r4)
                       case(4)
                          nout(1) = size(indata_3d_r4,DIM=1)
                          nout(2) = size(indata_3d_r4,DIM=2)
                          nout(3) = size(indata_3d_r4,DIM=3)
                          allocate (outdata_4d_r4(nout(1),nout(2),nout(3),1))
                          outdata_4d_r4(:,:,:,1) = indata_3d_r4(:,:,:)
                          iostat = NF90_PUT_VAR (ncid, field_id, outdata_4d_r4 )
                          deallocate (outdata_4d_r4)
                       case(5)
                          nout(1) = size(indata_4d_r4,DIM=1)
                          nout(2) = size(indata_4d_r4,DIM=2)
                          nout(3) = size(indata_4d_r4,DIM=3)
                          nout(4) = size(indata_4d_r4,DIM=4)
                          allocate (outdata_5d_r4(nout(1),nout(2),nout(3),nout(4),1))
                          outdata_5d_r4(:,:,:,:,1) = indata_4d_r4(:,:,:,:)
                          iostat = NF90_PUT_VAR (ncid, field_id, outdata_5d_r4 )
                          deallocate (outdata_5d_r4)
                       case default
                        supported = .false.
                   end select ! ndims
                case (.false.)
                   select case (ndims)
                       case(1)
                          supported = .false.
                       case(2)
                          iostat = NF90_PUT_VAR (ncid, field_id, indata_2d_r4 )
                       case(3)
                          iostat = NF90_PUT_VAR (ncid, field_id, indata_3d_r4 )
                       case(4)
                          iostat = NF90_PUT_VAR (ncid, field_id, indata_4d_r4 )
                       case default
                        supported = .false.
                   end select ! ndims
              end select ! implied_time_dim

           case('char','character','CHAR','CHARACTER')
              select case (implied_time_dim)
                case (.true.)
                   select case (ndims)
                       case default
                        supported = .false.
                   end select ! ndims
                case (.false.)
                   select case (ndims)
                       case(2)
                          do n=1,io_dims(2)%length
                            start(1) = 1
                            start(2) = n
                            count(1)=len_trim(indata_1d_ch(n))
                            count(2)=1
                            iostat = NF90_PUT_VAR (ncid, field_id, &
                                     trim(indata_1d_ch(n)), &
                                     start=start,count=count)
                          enddo
                       case default
                        supported = .false.
                   end select ! ndims
              end select ! implied_time_dim
           case default
         end select ! nftype


         if (iostat /= nf90_noerr) then
            call check_status(iostat)
            write_error = .true.
         endif

      endif ! master task

!-----------------------------------------------------------------------
!
! check for errors
!
!-----------------------------------------------------------------------

   call broadcast_scalar(write_error, master_task)
   if (write_error) call exit_POP(sigAbort, &
         '(write_nstd_netcdf) Error writing field to netCDF file')

   call broadcast_scalar(supported, master_task)
   if (.not. supported) call exit_POP(sigAbort, &
         '(write_nstd_netcdf) option not supported')

!-----------------------------------------------------------------------
!EOC

 end subroutine write_nstd_netcdf


!***********************************************************************
!BOP
! !IROUTINE: define_dimensions
! !INTERFACE:

 subroutine define_dimensions(data_file,ndims,io_dims)

! !DESCRIPTION:
! This routine defines dimensions, if they are not already defined
!
! !REVISION HISTORY:
! same as module

! !INPUT PARAMETERS:

   type (datafile), intent (in) :: &
      data_file

   integer (int_kind), intent (in) :: &
      ndims

! !INPUT/OUTPUT PARAMETERS:

   type (io_dim), dimension(ndims), intent(inout) :: &
      io_dims


!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   integer :: &
      iostat, & ! netCDF status flag
      dimid, &
      ncid, &
      n

   ncid = data_file%id(1)

!-----------------------------------------------------------------------
!
! define the dimensions
!
!-----------------------------------------------------------------------

   if (my_task == master_task) then
      do n = 1,ndims
         dimid = 0

         !*** check to see whether dimension is already defined
         iostat = NF90_INQ_DIMID(ncid=ncid, name=trim(io_dims(n)%name),&
                                 dimid=dimid)
         if (iostat /= NF90_NOERR) then ! dimension not yet defined
            iostat = NF90_DEF_DIM (ncid=ncid, name=trim(io_dims(n)%name), &
                                   len=io_dims(n)%length, dimid=io_dims(n)%id)
         else
            io_dims(n)%id = dimid
         end if
      end do
   endif ! master_task


!-----------------------------------------------------------------------
!EOC

 end subroutine define_dimensions


!***********************************************************************
!BOP
! !IROUTINE: define_var
! !INTERFACE:

 subroutine define_var (data_file,short_name,ndims,io_dims, &
                        xtype,field_id)

! !DESCRIPTION:
! This routine defines a netCDF variable
!
! !REVISION HISTORY:
! same as module

! !INPUT PARAMETERS:

   type (datafile), intent (in) :: &
      data_file

   character(*), intent (in) :: &
      short_name

   integer (int_kind), intent (in) :: &
      ndims, &
      xtype

! !INPUT/OUTPUT PARAMETERS:

   type (io_dim), dimension(ndims) :: &
      io_dims

! !OUTPUT PARAMETERS:

   integer (i4), intent(out) :: &
      field_id

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   integer :: &
      iostat ! netCDF status flag

   integer :: &
      ncid, &
      dimid, &
      n

   logical (log_kind) :: &
      define_error ! error flag
!-----------------------------------------------------------------------
!
! define the field
!
!-----------------------------------------------------------------------

   define_error = .false.
   ncid = data_file%id(1)

   if (my_task == master_task) then
      !*** check to see whether field of this name already defined.

      iostat = NF90_INQ_VARID(ncid, trim(short_name), field_id)

      if (iostat /= NF90_NOERR) then ! variable was not yet defined

            iostat = NF90_DEF_VAR (ncid=ncid,name=trim(short_name), &
                                   xtype=xtype, &
                                   dimids=(/ (io_dims(n)%id, n=1,ndims) /),&
                                   varid=field_id)
         call check_status(iostat)
         if (iostat /= nf90_noerr) define_error = .true.
      end if
   end if ! master task

   call broadcast_scalar(define_error, master_task)

   if (define_error) then
       write(stdout,*) '(define_var) Error for field = ', trim(short_name)
       call exit_POP(sigAbort, 'Error defining nonstandard CCSM netCDF field')
   endif


 end subroutine define_var

!***********************************************************************
!BOP
! !IROUTINE: check_file_open
! !INTERFACE:

 subroutine check_file_open(data_file, name)

! !DESCRIPTION:
! This utility routine checks if the data file has been opened
!
! !REVISION HISTORY:
! same as module

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (in) :: &
      data_file

   character(*),intent (in) :: name

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   integer :: &
      iostat ! netCDF status flag

   logical (log_kind) :: &
      define_error ! error flag

   character (char_len) :: string


!-----------------------------------------------------------------------
!
! make sure file has been opened
!
!-----------------------------------------------------------------------

   define_error = .false.

   if (data_file%id(1) <= 0) then
      define_error = .true.
   endif

   call broadcast_scalar(define_error, master_task)
   if (define_error) &
     call exit_POP(sigAbort, &
                   '('/&
                      &/trim(name)/&
                      &/') attempt to define field without opening file first')


!-----------------------------------------------------------------------
!EOC

 end subroutine check_file_open


!***********************************************************************
!BOP
! !IROUTINE: check_definemode
! !INTERFACE:

 subroutine check_definemode (data_file, name)

! !DESCRIPTION:
! This utility routine checks if the data file is in define mode
!
! !REVISION HISTORY:
! same as module

! !INPUT/OUTPUT PARAMETERS:

   type (datafile), intent (in) :: &
      data_file

   character(*),intent (in):: name

!EOP
!BOC
!-----------------------------------------------------------------------
!
! local variables
!
!-----------------------------------------------------------------------

   integer :: &
      iostat ! netCDF status flag

   logical (log_kind) :: &
      write_error ! error flag

   character (char_len) :: string


!-----------------------------------------------------------------------
!
! make sure file is in define mode
!
!-----------------------------------------------------------------------


   if (.not. data_file%ldefine) &
     call exit_POP(sigAbort, &
                   '('/&
                      &/trim(name)/&
                      &/') attempt to define field but not in define mode')

!-----------------------------------------------------------------------
!EOC

 end subroutine check_definemode


!***********************************************************************
 end module io_netcdf

!|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
