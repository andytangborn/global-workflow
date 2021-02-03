#!/bin/ksh -x

###############################################################
## Abstract:
## Get GFS intitial conditions
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEgfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current date (YYYYMMDDHH)
## CDUMP  : cycle name (gdas / gfs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

###############################################################
# Source FV3GFS workflow modules
. $HOMEgfs/ush/load_fv3gfs_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base init"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

###############################################################
# Source machine runtime environment
. $BASE_ENV/${machine}.env init
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Set script and dependency variables

yy=$(echo $CDATE | cut -c1-4)
mm=$(echo $CDATE | cut -c5-6)
dd=$(echo $CDATE | cut -c7-8)
hh=${cyc:-$(echo $CDATE | cut -c9-10)}

EXTRACT_DIR=${PTMP}/gdas.init_${CDATE}/input
WORKDIR=${PTMP}/gdas.init_${CDATE}/output
OUTDIR=${ROTDIR}

COMPONENT="atmos"

gfs_ver=v16
RUNICSH=${GDASINIT_DIR}/run_v16.chgres.sh

# No ENKF data prior to 2012/05/21/00z
if [ $yy$mm$dd$hh -lt 2012052100 ]; then
  set +x
  echo FATAL ERROR: SCRIPTS DO NOT SUPPORT OLD GFS DATA
  exit 2
elif [ $yy$mm$dd$hh -lt 2016051000 ]; then
  gfs_ver=v12
  RUNICSH=${GDASINIT_DIR}/run_pre-v14.chgres.sh
elif [ $yy$mm$dd$hh -lt 2017072000 ]; then
  gfs_ver=v13
  RUNICSH=${GDASINIT_DIR}/run_pre-v14.chgres.sh
elif [ $yy$mm$dd$hh -lt 2019061200 ]; then
  gfs_ver=v14
  RUNICSH=${GDASINIT_DIR}/run_${gfs_ver}.chgres.sh
elif [ $yy$mm$dd$hh -lt 2021020300 ]; then
  gfs_ver=v15
  RUNICSH=${GDASINIT_DIR}/run_${gfs_ver}.chgres.gfs.sh
fi

export EXTRACT_DIR yy mm dd hh UFS_DIR OUTDIR CRES_HIRES CRES_ENKF
export LEVS gfs_ver

# Run chgres_cube
if [ ! -d $OUTDIR ]; then mkdir -p $OUTDIR ; fi
sh ${RUNICSH} ${CDUMP}
status=$?
[[ $status -ne 0 ]] && exit $status

# Copy pgbanl file to ROTDIR for verification/archival - v14+
if [ $gfs_ver = v14 -o $gfs_ver = v15 ]; then
  cd $EXTRACT_DIR
  for grid in 0p25 0p50 1p00
  do
    file=gfs.t${hh}z.pgrb2.${grid}.anl
    mv ${EXTRACT_DIR}/${CDUMP}.${yy}${mm}${dd}/${hh}/${file} ${OUTDIR}/${CDUMP}.${yy}${mm}${dd}/${hh}/${COMPONENT}/${file}
  done
fi

# Clean up EXTRACT_DIR
rm -rf $EXTRACT_DIR

###############################################################
# Exit out cleanly
exit 0
