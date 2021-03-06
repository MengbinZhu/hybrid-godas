module obscom_obsio
  use netcdf
  use datetime_module

  implicit none
  private


  ! public types
  public :: obsio_nc



  !============================================================  
  type :: obsio_nc
     !! class to read and write observations in NetCDF format
   contains
     procedure :: get_name => obsio_get_name
     procedure :: get_desc => obsio_get_desc     
     procedure :: write    => obs_write_nc
     procedure :: read     => obs_read_nc

  end type obsio_nc
  !============================================================


  type, public :: observation
     integer :: id = -1
     integer :: plat
     real :: lat
     real :: lon
     real :: dpth
     real :: hr
     real :: val
     real :: err
     integer :: qc
  end type observation
  



contains


  
  
  !============================================================
  function obsio_get_name(self)
    class(obsio_nc) :: self
    character(:), allocatable :: obsio_get_name
    obsio_get_name = "LETKF_NC"

  end function obsio_get_name
  !============================================================


  

  !============================================================
  function obsio_get_desc(self)
    class(obsio_nc) :: self
    character(:), allocatable :: obsio_get_desc
    obsio_get_desc = "netCDF observation I/O"

  end function obsio_get_desc
  !============================================================
   
  

  
  !============================================================
  subroutine obs_write_nc(self, file, obs, basedate, inc)
    class(obsio_nc) :: self
    character(len=*),  intent(in) :: file
    type(observation), intent(in) :: obs(:)
    type(datetime),    intent(in) :: basedate
    real, optional,    intent(in) :: inc(:)
    
    integer :: nobs, n
    integer :: ncid, dimid, varid
    integer,  allocatable :: tmp_i(:)
    real(4), allocatable :: tmp_r(:)

    type(timedelta) :: td


    nobs = size(obs)
    allocate(tmp_i(nobs))
    allocate(tmp_r(nobs))

    ! create file definition
    call check( nf90_create(file, nf90_clobber, ncid))

    call check( nf90_def_dim(ncid, "time", 1, dimid))
    call check( nf90_def_var(ncid, "time", nf90_int, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "reference time of observation file"))
    call check( nf90_put_att(ncid, varid, "units", "seconds since 1970-01-01 00:00:00"))

    call check( nf90_def_dim(ncid, "obs",  nf90_unlimited, dimid))
    call check( nf90_def_var(ncid, "obid",  nf90_short,  dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "observation ID number"))

    call check( nf90_def_var(ncid, "plat",  nf90_short,  dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "platform ID number"))
    call check( nf90_put_att(ncid, varid, "missing_value", 0))
    
    call check( nf90_def_var(ncid, "lat",   nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "latitude"))
    call check( nf90_put_att(ncid, varid, "units", "degrees"))

    call check( nf90_def_var(ncid, "lon",   nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "longitude"))
    call check( nf90_put_att(ncid, varid, "units", "degrees"))
    
    call check( nf90_def_var(ncid, "depth", nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "depth/height"))
    
    call check( nf90_def_var(ncid, "hr",  nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "time difference from reference time"))
    call check( nf90_put_att(ncid, varid, "units", "hours"))

    call check( nf90_def_var(ncid, "val",   nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "observation value"))

    if(present(inc)) then
       call check( nf90_def_var(ncid, "inc", nf90_real, dimid, varid))
       call check( nf90_put_att(ncid, varid, "long_name", "observation increment"))
    end if

    call check( nf90_def_var(ncid, "err",   nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "observation error"))

    call check( nf90_def_var(ncid, "qc",    nf90_byte,  dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "quality control, 0=good, >0 is bad"))

    call check( nf90_enddef(ncid))

    !============================================================
    call check( nf90_inq_varid(ncid, "time", varid))
    td = basedate-datetime(1970,1,1,0)
    call check( nf90_put_var(ncid, varid, td%total_seconds()))

    ! write observations
    do n=1, nobs
       tmp_i(n) = obs(n)%id
    end do
    call check( nf90_inq_varid(ncid, "obid", varid))
    call check( nf90_put_var(ncid, varid, tmp_i))

    do n=1, nobs
       tmp_i(n) = obs(n)%plat
    end do
    call check( nf90_inq_varid(ncid, "plat", varid))
    call check( nf90_put_var(ncid, varid, tmp_i))

    do n=1, nobs
       tmp_r(n) = obs(n)%lat
    end do
    call check( nf90_inq_varid(ncid, "lat", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))
    
    do n=1, nobs
       tmp_r(n) = obs(n)%lon
    end do
    call check( nf90_inq_varid(ncid, "lon", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))
    
    do n=1, nobs
       tmp_r(n) = obs(n)%dpth
    end do
    call check( nf90_inq_varid(ncid, "depth", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))
    
    do n=1, nobs
       tmp_r(n) = obs(n)%hr
    end do
    call check( nf90_inq_varid(ncid, "hr", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))
    
    do n=1, nobs
       tmp_r(n) = obs(n)%val
    end do
    call check( nf90_inq_varid(ncid, "val", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))

    if(present(inc)) then
       call check( nf90_inq_varid(ncid, "inc", varid))
       call check( nf90_put_var(ncid, varid, inc))
    end if

    do n=1, nobs
       tmp_r(n) = obs(n)%err
    end do
    call check( nf90_inq_varid(ncid, "err", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))
    
    do n=1, nobs
       tmp_i(n) = obs(n)%qc
    end do
    call check( nf90_inq_varid(ncid, "qc", varid))
    call check( nf90_put_var(ncid, varid, tmp_i))
    
    ! all done, cleanup    
    call check( nf90_close(ncid))
    
    deallocate(tmp_i)
    deallocate(tmp_r)
    
  end subroutine obs_write_nc
  !============================================================
  


  !============================================================
  subroutine obs_read_nc(self, file, obs, basedate, inc)
    class(obsio_nc) :: self
    character(len=*),  intent(in) :: file
    type(observation), allocatable, intent(out) :: obs(:)
    type(datetime),    intent(out) :: basedate
    real, optional,allocatable,    intent(out) :: inc(:)

     integer :: nobs, n , stat
     integer :: ncid, dimid, varid
     integer, allocatable :: tmp_i(:)
     real(4), allocatable :: tmp_r(:)


     ! open the file
     call check( nf90_open(file, nf90_nowrite, ncid) )
     call check( nf90_inq_dimid(ncid, "obs", dimid))
     call check( nf90_inquire_dimension(ncid, dimid, len=nobs))

     ! allocate space depending on number of observations
     allocate(tmp_i(nobs))
     allocate(tmp_r(nobs))
     allocate(obs(nobs))

     ! read in the variables
     call check( nf90_inq_varid(ncid, "time", varid))
     call check( nf90_get_var(ncid, varid, n))
     basedate=datetime(1970,1,1,0)+timedelta(seconds=n)

     call check( nf90_inq_varid(ncid, "obid", varid))
     call check( nf90_get_var(ncid, varid, tmp_i))
     do n=1,nobs
        obs(n)%id = tmp_i(n)
     end do

     call check( nf90_inq_varid(ncid, "plat", varid))
     call check( nf90_get_var(ncid, varid, tmp_i))
     do n=1,nobs
        obs(n)%plat = tmp_i(n)
     end do

     call check( nf90_inq_varid(ncid, "lat", varid))
     call check( nf90_get_var(ncid, varid, tmp_r))
     do n=1,nobs
        obs(n)%lat = tmp_r(n)
     end do

     call check( nf90_inq_varid(ncid, "lon", varid))
     call check( nf90_get_var(ncid, varid, tmp_r))
     do n=1,nobs
        obs(n)%lon = tmp_r(n)
     end do

     call check( nf90_inq_varid(ncid, "depth", varid))
     call check( nf90_get_var(ncid, varid, tmp_r))
     do n=1,nobs
        obs(n)%dpth = tmp_r(n)
     end do

     call check( nf90_inq_varid(ncid, "hr", varid))
     call check( nf90_get_var(ncid, varid, tmp_r))
     do n=1,nobs
        obs(n)%hr = tmp_r(n)
     end do

     call check( nf90_inq_varid(ncid, "val", varid))
     call check( nf90_get_var(ncid, varid, tmp_r))
     do n=1,nobs
        obs(n)%val = tmp_r(n)
     end do

     if (present(inc)) then
        stat = nf90_inq_varid(ncid, "inc", varid)
        if(stat == nf90_noerr) then
           allocate(inc(nobs))
           call check(nf90_get_var(ncid, varid, inc))
        end if
     end if

     call check( nf90_inq_varid(ncid, "err", varid))
     call check( nf90_get_var(ncid, varid, tmp_r))
     do n=1,nobs
        obs(n)%err = tmp_r(n)
     end do

     call check( nf90_inq_varid(ncid, "qc", varid))
     call check( nf90_get_var(ncid, varid, tmp_i))
     do n=1,nobs
        obs(n)%qc = tmp_i(n)
     end do

     ! close / cleanup
     call check( nf90_close(ncid))
     deallocate(tmp_i)
     deallocate(tmp_r)
  end subroutine obs_read_nc
  !============================================================




  !============================================================
  subroutine check(status)
    integer, intent(in) :: status

    if(status /= nf90_noerr) then
       write (*,*) trim(nf90_strerror(status))
       stop 1
    end if
  end subroutine check
  !============================================================



end module obscom_obsio
