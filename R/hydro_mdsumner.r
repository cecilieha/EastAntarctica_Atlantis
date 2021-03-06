`#NB!!!!!!!!!
# after running this program you need to rename the timedimension, as R doen't allow
# same names of dimensions and variables. Use nco and write the following
# ncrename -d t1,t filename.nc newfilename.nc, and you're ready to go.
#libraries
library(ncdf4)
library(pracma)
library(maptools)


# load in the polygon (lon, lat) corner coordinate locations:
cb <- readShapePoly("shapefilename.shp")
bgm <- rbgm::bgmfile(bgmfiles::bgmfiles("antarctica_28"))

## zero based?
box_id <- bgm$boxes$.bx0
#box_id<-sort(as.numeric(paste(unique(cb$box_id))))                                                        ########

h_get <- c(20, 400, 750, 1000, 2000, 4000) * -1
#h_get = c(25,100,200,300, 425, 750, 1200)*-1  # Depth ranges (m) to interpolate currents to
dz = 20 		# Depth interval (m) for vertical decimation
Nt_get = c(1)		# Time ranges to process from NetCDF file - ant tidssteg

year_all=c(1) #define over which period you'd like to calculate the forcing files (each year will be written in a separate file)
## derived from the file
##days = c(1:31) # nr of records in each file     
daymean <- 1 # in noba the roms files are 5-day means
w=c(1) #linear weights for converting from 5-day means to daily fields

#corners <- read.table("lon_lat_info_file", header=T) # you need information about lon/lat coordinates for each face. I think this can be loaded directly from the shape file.
#boxes = 1:(max(corners$Area)+1) #nr of polygons
boxes <- seq_len(nrow(bgm$boxes))

library(dplyr)
corners <- bgm$boxes %>% select(.bx0, area) %>% 
  inner_join(bgm$facesXboxes) %>% inner_join(bgm$faces, c("iface" = ".fx0")) %>% 
  inner_join(bgm$facesXverts, c("iface" = ".fx0")) %>% inner_join(bgm$vertices) %>% 
  select(area, x, y, .bx0)

#at most 6 timesteps in each file, hence
max_Ni = 6
t_temp=array(NA,dim=c(length(boxes),length(h_get),length(days)*max_Ni))
t_saln=array(NA,dim=c(length(boxes),length(h_get),length(days)*max_Ni))
t_boxn=array(NA,dim=c(length(boxes),length(h_get),length(days)*max_Ni))

nlay = length(h_get)
# calculate on subset instead of whole area 
#NB! hardcoded to cpolar MDSUMNER
x1=1
x2=1442  ## xi_u
xt=x2-x1
#
y1=1  
y2=392 ## 
yt=y2-y1 

#the info on landmask, csr etc should be part of your romsfile - check
mask.file="filename_roms.nc"
m.f=nc_open(mask.file)
mask_rho = ncvar_get(m.f, "mask_rho") # mask on RHO-points; all 0 or 1, dim( 507 329 )
Cs_r = ncvar_get(m.f, "Cs_r") # S-coordinate stretching curves at RHO-points 
s_rho = ncvar_get(m.f, "s_rho")
h = ncvar_get(m.f, "h")
nc_close(m.f)

for (y in year_all){ #NB! valid if you have forcing files with year included in names, otherwise rewrite the loop 
  print(y)
  years=y
  cnt=1
  for (d in days){
    print(d)
    f.path=paste("path_to_roms_files",years,sep="/")
    filename = paste("day_",years,'_', formatC(d,width=2,flag="0"), ".nc", sep="")
    file=paste(f.path,filename,sep="/")
    ex.cb = nc_open(file)   
    
    
    ocean_time = ncvar_get( ex.cb, "ocean_time" )  # 
    lon_rho=ncvar_get( ex.cb, "lon_rho" ) # 
    lat_rho= ncvar_get( ex.cb, "lat_rho") # 
    zeta = ncvar_get( ex.cb, "zeta") # 
    temp = ncvar_get( ex.cb, "temp" ) #
    salt = ncvar_get( ex.cb, "salt" ) # 
    hc = 2 #ncvar_get( ex.cb, "hc") # 
    nc_close(ex.cb)
    
    # Get the horizontal, vertical, and time dimensions of the data
    Nx = dim(mask_rho)[1]
    Ny = dim(mask_rho)[2]
    Nz=dim(temp)[3]
    Nt=length(ocean_time)
    
    # if the time record chosen is not in the file, then exit:
    if (max(Nt_get) > Nt) {
      print('The time record exceeds the available number ....')	
    } else {
      print('Ready to Go!')
    }
    
    # Calculate the number of depth intervals to average u, v, T and S over:
    Ni=length(h_get)
    # Calculate the number of time intervals to average u, v, T and S over:
    #Ti = length(Nt_get)
    Ti=Nt # Several time steps in each file
    
    
    # define arrays at internal rho-points to average velocities to and get the
    # variables at these point locations
    x_sub=array(1,dim=c(xt-2,yt-2))
    y_sub=array(1,dim=c(xt-2,yt-2))
    temp_sub=array(1,dim=c(xt-2,yt-2,Ni,Ti))
    salt_sub=array(1,dim=c(xt-2,yt-2,Ni,Ti))
    
    temp_tmp=array(1,dim=c(xt-2,yt-2,Nz,Nt))  #need Nt as for some reason several days are stored in same file.
    salt_tmp=array(1,dim=c(xt-2,yt-2,Nz,Nt))
    
    x_sub=lon_rho[(x1+1):(x2-2),(y1+1):(y2-2)]
    y_sub=lat_rho[(x1+1):(x2-2),(y1+1):(y2-2)]
    
    
    m_sub=drop(mask_rho[(x1+1):(x2-1),(y1+1):(y2-1)]) # does mr=mask_rho? cuz mask_rho has no single
    h_sub=drop(h[(x1+1):(x2-1),(y1+1):(y2-1)]) #dim(h[2:(Nx-1),2:(Ny-1)]) = 330, 289 = dim(h_sub)
    
    temptemp= temp 
    saltsalt= salt 
    
    if(Ti==1){
      zeta_sub= drop(zeta[(x1+1):(x2-1),(y1+1):(y2-1)])     
    }else{
      zeta_sub= drop(zeta[(x1+1):(x2-1),(y1+1):(y2-1),])     
    }
    
    zetazeta<- zeta #drop(zeta[,,Nt_get])
    
    #Exclude land velocity values and set the .. to zero if necessary:
    
    length(which(temptemp<1000000))/length(temptemp) # = 0.199157, ie, ~20% of uu is usable values
    
    II= which(abs(temptemp)>1000000) # NB!!! this can be model dependent! - check your fill values 
    if (length(II)!=0) temptemp[II]=0
    
    II= which(abs(saltsalt)<5) #NB!!!!! this can be model dependent - check fill values!
    if (length(II)!=0) saltsalt[II] =0
    
    # Average temperature and salinities to internal rho-point locations:
    
    if(Ti==1){
      temp_tmp[,,,1]=0.5*(drop(temptemp[x1:(x1+xt-3),(y1+2):(y2-1),])+drop(temptemp[(x1+1):(x1+xt-2),(y1+2):(y2-1),]))
    }else{
      temp_tmp=0.5*(drop(temptemp[x1:(x1+xt-3),(y1+2):(y2-1),,])+drop(temptemp[(x1+1):(x1+xt-2),(y1+2):(y2-1),,]))
    }
    
    # For checking the values
    # filled.contour(temp_tmp[,,30,1]) #nb! roms is "upside-down", hence layer 30 is surface.
    
    if(Ti==1){
      salt_tmp[,,,1]=0.5*(drop(saltsalt[(x1+2):(x2-1),(y1+1):(y1+yt-2),])+drop(saltsalt[(x1+2):(x2-1),(y1+2):(y1+yt-1),]))
    }else{
      salt_tmp=0.5*(drop(saltsalt[(x1+2):(x2-1),(y1+1):(y1+yt-2),,])+drop(saltsalt[(x1+2):(x2-1),(y1+2):(y1+yt-1),,]))
    }
    
    for (i in 1:(xt-2)) {  
      for (j in 1:(yt-2)) {  #
        if (m_sub[i,j]>0.5) { 
          if (Ti==1) TiLoop = 1
          if (Ti > 1 ) TiLoop = Ti 
          for (tm in 1:TiLoop){  
            z0=(s_rho-Cs_r)*(hc)+ Cs_r*h_sub[i,j]
            if (Ti > 1) {
              zr=z0+mean(zeta_sub[i,j,tm])*(1.0 + z0/h_sub[i,j])
            }else{
              zr=z0+mean(zeta_sub[i,j])*(1.0 + z0/h_sub[i,j])
            }
            # Top depth interval:
            if (Ni >1 )   { # if you have > 1 depth layer
              tailzr = length(zr)
              if (tail(zr,1) < h_get[2])  zr[tailzr] <- tail(zr,1) + 1.5*dz
            }
            
            # Decimate the vertical u, v, T, S values
            
            zrv=seq(zr[1],tail(zr,1),by=dz)
            tempi=interp1(as.vector(zr),drop(temp_tmp[i,j,,tm]),zrv,method='linear')
            salti=interp1(as.vector(zr),drop(salt_tmp[i,j,,tm]),zrv,method='linear')
            
            if (Ni > 1) { 
              for (km in 1:(Ni-1)) { # Ni = length(h_get), i.e. depth
                II = which((zrv >= h_get[km+1]) & (zrv < h_get[km]))
                if ( length(II) != 0 ) {
                  temp_sub[i,j,km,tm] = mean(tempi[II])
                  salt_sub[i,j,km,tm] = mean(salti[II])
                }
              }
            }
            
            II=which(zrv <= h_get[Ni])
            if (length(II) != 0) {
              temp_sub[i,j,Ni,tm]=mean(tempi[II])
              salt_sub[i,j,Ni,tm]=mean(salti[II])
            }
          } #end Tiloop 
        }
      } # end j
    } # end i
    
    
    ############# fjerne NA-verdier u_sub og v_sub
    
    temp_sub2=temp_sub
    temp_sub2[which(temp_sub2==1.00000,arr.ind=TRUE)]=NA
    
    salt_sub2=salt_sub
    salt_sub2[which(salt_sub2==1.00000,arr.ind=TRUE)]=NA
    
    ###################
    
    
    # Extract the finite velocity values and their (lon, lat) locations
    
    if (Ti == 1 ) TiLoop = 1
    #if (Ti > 1 ) TiLoop = Ti - 1
    if (Ti > 1 ) TiLoop = Ti 
    
    len = length(box_id)
    final = (array(0, dim=c(length(box_id),4,Ni,TiLoop)))
    
    
    for (tm in 1:TiLoop) { # loop by time
      for (km in 1:Ni) { # loop by depth
        qq = salt_sub2[,,km,tm] # get the depth and time levels looping through now
        if (length(which(is.finite(qq)))>0) {
          
          II=is.finite(qq) # true false
          
          x_fin=x_sub[II] #  lon's
          y_fin=y_sub[II] # lats
          qq=drop(temp_sub2[,,km,tm]);temp_fin=qq[II]
          qq=drop(salt_sub2[,,km,tm]);salt_fin=qq[II]
          
          coordssat=SpatialPoints(coord=cbind(x_fin,y_fin))
          JJ<-overlay(coordssat,cb)
          
          a=0
          for (i in 1:length(box_id)) { # for km = 4 and i = 92
            # this gives me the index of the cb section, not the JJ!
            cb_get<- which(cb$box_id == box_id[i]) # 
            a = a+1
            if (length(cb_get) > 0) {
              JJ_get<-overlay(coordssat, cb[cb_get,]) # NB! will give warning:  'overlayPointsWithPolygons' is deprecated. Use 'over' instead. BUT! Over doesn't give the same results.
              
              x_mean=mean(x_fin[which(is.finite(JJ_get))], na.rm=TRUE)
              y_mean=mean(y_fin[which(is.finite(JJ_get))], na.rm=TRUE)
              salt_mean=mean(salt_fin[which(is.finite(JJ_get))], na.rm=TRUE)
              temp_mean=mean(temp_fin[which(is.finite(JJ_get))], na.rm=TRUE)
              rbind(x_mean, y_mean, salt_mean,temp_mean)
              
              final[a,1,km,tm]=x_mean
              final[a,2,km,tm]=y_mean
              final[a,3,km,tm]=salt_mean
              final[a,4,km,tm]= temp_mean
            }
            
          }
        }
      } #end of depth loop
    } #end of time loop
    
    
    f_temp=drop(final[,4,,])
    f_saln=drop(final[,3,,])
    
    #####################   
    #program to interpolate from 3-day means to daily values
    
    t_temp[,,cnt:(cnt+Ti-1)]=f_temp
    t_saln[,,cnt:(cnt+Ti-1)]=f_saln
    cnt=cnt+Ti
  } # loop by day   
  
  #remove access entries
  t_temp=t_temp[,,1:(cnt-1)]
  t_saln=t_saln[,,1:(cnt-1)]
  
  #interpolate between - to get daily values. Each field is a mean over the number of days specified in daymean
  temp_fin=array(NA,dim=c(length(boxes),length(h_get),(cnt-1)*daymean))
  saln_fin=array(NA,dim=c(length(boxes),length(h_get),(cnt-1)*daymean))
  
  
  
  jcnt=1
  for (i in 1:(cnt-2)){
    for(j in 1:(length(w)-1)){
      temp_fin[,,jcnt+j-1]=t_temp[,,i]*w[j]+t_temp[,,i+1]*w[(length(w)-j)]  
      saln_fin[,,jcnt+j-1]=t_saln[,,i]*w[j]+t_saln[,,i+1]*w[(length(w)-j)]  
    }
    jcnt=jcnt+daymean
  }
  
  if((jcnt-daymean)<365 & cnt>360){ #length other than 365 messes things up in long runs
    temp_fin[,,(jcnt:365)]=temp_fin[,,jcnt-daymean]
    saln_fin[,,(jcnt:365)]=saln_fin[,,jcnt-daymean]
  }
  
  #temporary arrays
  temp_nc_temp=array(NA,dim=c((length(h_get)+1),(max(corners$Area)+1),dim(temp_fin)[3])) # max neighbours set to 20 for now
  saln_nc_temp=array(NA,dim=c((length(h_get)+1),(max(corners$Area)+1),dim(saln_fin)[3])) # max neighbours set to 20 for now
  
  temp_nc_temp[1:7,,]=aperm(temp_fin,c(2,1,3))
  saln_nc_temp[1:7,,]=aperm(saln_fin,c(2,1,3))
  #sediment layer
  temp_nc_temp[8,,]=temp_fin[,7,]
  saln_nc_temp[8,,]=saln_fin[,7,]
  
  #define arrays to be printed to ncfile
  temp_nc=array(NA,dim=c((length(h_get)+1),(max(corners$Area)+1),dim(temp_fin)[3])) # max neighbours set to 20 for now
  saln_nc=array(NA,dim=c((length(h_get)+1),(max(corners$Area)+1),dim(saln_fin)[3])) # max neighbours set to 20 for now
  
  #NB!!!!! the layers has to be corrsponding to the biol.nc file - hence if the box has four layers: l4 l3 l2 l1 x x x s1, where s1==l4.
  
  for(i in boxes){
    rb=which(corners$Area==(i-1),arr.ind=T)
    nrlay=corners$nrLayers[rb[1]]
    if(nrlay==0){
      temp_nc=temp_nc_temp
    }else{
      for(j in 1:nrlay){
        temp_nc[j,,]=temp_nc_temp[nrlay-j+1,,]
        saln_nc[j,,]=saln_nc_temp[nrlay-j+1,,]
      }
      if(nrlay<7){
        e.l=7-nrlay
        for(k in 1:e.l){
          temp_nc[(nrlay+k),,]=temp_nc_temp[1,,]
          saln_nc[(nrlay+k),,]=saln_nc_temp[1,,]
        }
      }
      temp_nc[8,,]=temp_nc_temp[nrlay,,]
      saln_nc[8,,]=saln_nc_temp[nrlay,,]
    }
  }
  
  #create time - easier than to store the info all the way. 
  fday=days[1]
  f.path=paste("ROMSDIR",years,sep="/")
  f.time = paste(f.path,"ROMSFILENAME.nc", sep="")
  nc_t=nc_open(f.time)
  time=ncvar_get(nc_t,"ocean_time")
  t_start=time[1]
  dt=86400
  t_stop=t_start+(dim(temp_nc)[3]-1)*86400
  t_tot=seq(t_start,t_stop,dt)
  
  
  #filename
  f.temp=paste("temp_",years,"_d_",days[1],"_to_d_",days[length(days)],".nc",sep="")
  f.saln=paste("saln_",years,"_d_",days[1],"_to_d_",days[length(days)],".nc",sep="")
  
  #define dimensions
  dimb=ncdim_def("b","",boxes,create_dimvar=FALSE)
  dimz=ncdim_def("z","",1:(nlay+1),create_dimvar=FALSE)
  dimt=ncdim_def("t1","",1:length(t_tot),unlim=TRUE)#,create_dimvar=FALSE)
  
  #create variables
  #NB!!!!!! Unlimited rec needs to be on the right - otherwise the program complains!
  var.t=ncvar_def("t","seconds since 2008-01-01 00:00:00 +10",dimt,0,prec="double")
  var.temp=ncvar_def("temperature","DegC",list(dimz,dimb,dimt),0,prec="double")
  var.saln=ncvar_def("salinity","psu",list(dimz,dimb,dimt),0,prec="double")
  
  dt=86400
  
  
  #create file
  nc_temp=nc_create(f.temp,list(var.t,var.temp))
  nc_saln=nc_create(f.saln,list(var.t,var.saln))
  
  #assign global attributes to temp file
  ncatt_put(nc_temp,0,"title","Temperature file, NoBa")
  ncatt_put(nc_temp,0,"geometry","Nordic.bgm")
  ncatt_put(nc_temp,0,"parameters","")
  
  #assign global attributes to saln file
  ncatt_put(nc_saln,0,"title","Salinity file, NoBa")
  ncatt_put(nc_saln,0,"geometry","Nordic.bgm")
  ncatt_put(nc_saln,0,"parameters","")
  
  #assign attributes to variables
  ncatt_put(nc_temp,var.t,"dt",86400,prec="double")
  ncatt_put(nc_saln,var.t,"dt",86400,prec="double")
  
  #assign variables to file
  ncvar_put(nc_temp,var.temp,temp_nc)
  ncvar_put(nc_saln,var.saln,saln_nc)
  
  nc_close(nc_temp)
  nc_close(nc_saln)
}