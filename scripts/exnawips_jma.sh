#!/bin/sh
###################################################################
echo "----------------------------------------------------"
echo "exnawips - convert JMA GRIB files into GEMPAK Grids"
echo "----------------------------------------------------"
echo "History: Apr 2008 - First implementation of this new script."
#
# Job runs 3 times per day on the CCS.  Once for the 0000Z cycle
# and twice for the 1200Z cycle.  The job runs twice for the 1200Z
# cycle because the JMA GRIB data comes into the CCS in two spurts,
# the first at approximately 1530Z, the second at approximately
# 1830Z.  The job runs to create GEMPAK files after the first 
# set of data comes in to give the forecasters a first look at the
# 1200Z data, then again after the rest of the data comes in to 
# create the final 1200Z files.
#
# M. Klein/HPC	04/25/2008	Fix problem with F00 when converted 
#                               with nagrib.
# SPA Team      Dec 2021        Minor Implementation Standards changes
#####################################################################

cd $DATA

set -xa
msg="Begin job for $job"
postmsg "$jlogfile" "$msg"

#
NAGRIB=nagrib_nc
GEMGRDN=outn.gem
GEMGRDS=outs.gem
PDY2=`echo $PDY | cut -c3-`
#

if [ -s ${DCOMIN}/jma_n_${cyc} ] ; then

 cpyfil=gds
 garea=dset
 gbtbls=
 maxgrd=4999
 kxky=
 grdarea=
 proj=
 output=T
  
$GEMEXE/$NAGRIB << EOF
   GBFILE   = ${DCOMIN}/jma_n_${cyc}
   INDXFL   = 
   GDOUTF   = $GEMGRDN
   PROJ     = $proj
   GRDAREA  = $grdarea
   KXKY     = $kxky
   MAXGRD   = $maxgrd
   CPYFIL   = $cpyfil
   GAREA    = $garea
   OUTPUT   = $output
   GBTBLS   = $gbtbls
   GBDIAG   = 
   PDSEXT   = $pdsext
  l
  r
EOF

###################################################################
# THERE IS A PROBLEM WITH THE 00-HOUR FORECAST TIME IN THE 
# OUTPUT GRID...THERE IS NO F000 AT THE END OF THE GRID DATE/TIME
# THIS CAUSES PROBLEMS DISPLAYING IN N-AWIPS.
# BELOW WILL ATTEMPT TO FIX THE PROBLEM.
##################################################################

$GEMEXE/gdinfo << EOF
   GDFILE  = $GEMGRDN
   LSTALL  = YES
   OUTPUT  = F/parms.txt
   GLEVEL  = ALL
   GDATTIM = $PDY2/${cyc}00
   GVCORD  = ALL 
   GFUNC   = ALL
   run

   exit
EOF

 if [ -f parms.txt ]; then
   numlines=`wc -l parms.txt | awk '{print $1}'`
   cnt=1

   while [ $cnt -le $numlines ]; do
       txtline=`cat parms.txt | head -n $cnt | tail -1`
       if [ `echo $txtline | grep -c "$PDY2/${cyc}00"` -eq 1 ]; then
         clev=`echo $txtline | awk '{print $3}'`
         cvcord=`echo $txtline | awk '{print $4}'`
         cparm=`echo $txtline | awk '{print $5}'`

         $GEMEXE/gddiag << EOF
          GDFILE  = $GEMGRDN
          GDOUTF  = $GEMGRDN
          GFUNC   = $cparm
          GDATTIM = $PDY2/${cyc}00
          GLEVEL  = $clev
          GVCORD  = $cvcord
          GRDNAM  = ${cparm}^$PDY2/${cyc}00F000
          GPACK   =
          GRDHDR  =
          PROJ    =
          GRDAREA =
          KXKY    =
          MAXGRD  = 4999
          CPYFIL  = $GEMGRDN
          ANLYSS  = 4/2;2;2;2
          run

          exit
EOF
        
         $GEMEXE/gddelt << EOF
          GDFILE  = $GEMGRDN
          GDATTIM = $PDY2/${cyc}00
          GLEVEL  = $clev
          GVCORD  = $cvcord
          GFUNC   = $cparm
          run

          exit
EOF

       fi
       let cnt=cnt+1
   done
   rm -f parms.txt
 fi

  export err=$?;err_chk

 #####################################################
 # GEMPAK DOES NOT ALWAYS HAVE A NON ZERO RETURN CODE
 # WHEN IT CAN NOT PRODUCE THE DESIRED GRID.  CHECK
 # FOR THIS CASE HERE.
 #####################################################

 ls -l $GEMGRDN
 export err=$?;export pgm="GEMPAK CHECK FILE";err_chk

 #####################################################
 # Move the file to /com and issue the DBNet alert
 #####################################################

 if [ $SENDCOM = "YES" ] ; then
   mv $GEMGRDN $COMOUT/${RUN}_${PDY}${cyc}_N
   if [ $SENDDBN = "YES" ] ; then
       $DBNROOT/bin/dbn_alert MODEL JMA_GEMPAK $job \
         $COMOUT/${RUN}_${PDY}${cyc}_N
   else
       echo "##### DBN_ALERT_TYPE is: JMA_GEMPAK #####"
   fi
 fi

else

  echo "**************************************"
  echo "**************************************"
  echo " ${DCOMIN}/jma_n_${cyc} does not exist!!!"
  echo "**************************************"
  echo "**************************************"
fi

if [ -s ${DCOMIN}/jma_s_${cyc} ] ; then

 cpyfil=gds
 garea=dset
 gbtbls=
 maxgrd=4999
 kxky=
 grdarea=
 proj=
 output=T

$GEMEXE/$NAGRIB << EOF
   GBFILE   = ${DCOMIN}/jma_s_${cyc}
   INDXFL   =
   GDOUTF   = $GEMGRDS
   PROJ     = $proj
   GRDAREA  = $grdarea
   KXKY     = $kxky
   MAXGRD   = $maxgrd
   CPYFIL   = $cpyfil
   GAREA    = $garea
   OUTPUT   = $output
   GBTBLS   = $gbtbls
   GBDIAG   =
   PDSEXT   = $pdsext
  l
  r
EOF

###################################################################
# THERE IS A PROBLEM WITH THE 00-HOUR FORECAST TIME IN THE 
# OUTPUT GRID...THERE IS NO F000 AT THE END OF THE GRID DATE/TIME
# THIS CAUSES PROBLEMS DISPLAYING IN N-AWIPS.
# BELOW WILL ATTEMPT TO FIX THE PROBLEM.
##################################################################

$GEMEXE/gdinfo << EOF
   GDFILE  = $GEMGRDS
   LSTALL  = YES
   OUTPUT  = F/parms2.txt
   GLEVEL  = ALL
   GDATTIM = $PDY2/${cyc}00
   GVCORD  = ALL 
   GFUNC   = ALL
   run

   exit
EOF

 if [ -f parms2.txt ]; then
   numlines=`wc -l parms2.txt | awk '{print $1}'`
   cnt=1

   while [ $cnt -le $numlines ]; do
       txtline=`cat parms2.txt | head -n $cnt | tail -1`
       if [ `echo $txtline | grep -c "$PDY2/${cyc}00"` -eq 1 ]; then
         clev=`echo $txtline | awk '{print $3}'`
         cvcord=`echo $txtline | awk '{print $4}'`
         cparm=`echo $txtline | awk '{print $5}'`

         $GEMEXE/gddiag << EOF
          GDFILE  = $GEMGRDS
          GDOUTF  = $GEMGRDS
          GFUNC   = $cparm
          GDATTIM = $PDY2/${cyc}00
          GLEVEL  = $clev
          GVCORD  = $cvcord
          GRDNAM  = ${cparm}^$PDY2/${cyc}00F000
          GPACK   =
          GRDHDR  =
          PROJ    =
          GRDAREA =
          KXKY    =
          MAXGRD  = 4999
          CPYFIL  = $GEMGRDS
          ANLYSS  = 4/2;2;2;2
          run

          exit
EOF
        
         $GEMEXE/gddelt << EOF
          GDFILE  = $GEMGRDS
          GDATTIM = $PDY2/${cyc}00
          GLEVEL  = $clev
          GVCORD  = $cvcord
          GFUNC   = $cparm
          run

          exit
EOF

       fi
       let cnt=cnt+1
   done
   rm -f parms2.txt
 fi

 export err=$?;err_chk

 #####################################################
 # GEMPAK DOES NOT ALWAYS HAVE A NON ZERO RETURN CODE
 # WHEN IT CAN NOT PRODUCE THE DESIRED GRID.  CHECK
 # FOR THIS CASE HERE.
 #####################################################

 ls -l $GEMGRDS
 export err=$?;export pgm="GEMPAK CHECK FILE";err_chk

 #####################################################
 # Move the file to /com and issue the DBNet alert
 #####################################################

 if [ $SENDCOM = "YES" ] ; then
   mv $GEMGRDS $COMOUT/${RUN}_${PDY}${cyc}_S
   if [ $SENDDBN = "YES" ] ; then
       $DBNROOT/bin/dbn_alert MODEL JMA_GEMPAK $job \
         $COMOUT/${RUN}_${PDY}${cyc}_S
   else
       echo "##### DBN_ALERT_TYPE is: JMA_GEMPAK #####"
   fi
 fi

else

  echo "**************************************"
  echo "**************************************"
  echo " ${DCOMIN}/jma_s_${cyc} does not exist!!!"
  echo "**************************************"
  echo "**************************************"
fi

#####################################################################
# GOOD RUN
set +x
echo "**************JOB $job COMPLETED NORMALLY ON WCOSS2"
echo "**************JOB $job COMPLETED NORMALLY ON WCOSS2"
echo "**************JOB $job COMPLETED NORMALLY ON WCOSS2"
set -x
#####################################################################

msg='Job completed normally.'
echo $msg
postmsg "$jlogfile" "$msg"

############################### END OF SCRIPT #######################
