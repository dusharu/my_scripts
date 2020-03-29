#!/bin/bash
################################################################################
#                                                                              #
#                       Get Pulkovo Forecast                                   #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2016.05.17 #
################################################################################

#This is my METAR parser for conky.
#cp temperature_conky.sh ~/.temperature_conke.sh
#Data get from www.aviationweather.gov


############### VAR
declare -a FIELDS_NAME
declare -a FIELDS_VALUE
FIELDS_NAME=(AIRPORT TIME WIND VISIBILITI CLOUD TEMPERATURE PRESSURE ADD_INFO FORECAST_LANDING ADD_INFO_2)

############### GET
DATA_STRING=$(curl "https://www.aviationweather.gov/metar/data?ids=ulli&format=decoded&hours=0&taf=on&layout=on&date=0" 2>&1 |grep -e "Text:</span>" | sed -re 's/^.*(ULLI.*)<\/td>$/\1/g')
#DATA_STRING='ULLI 210800Z VRB01MPS 2500 -RA BR BKN002 13/12 Q1005 R10L/290050 NOSIG RMK QBB080 OBST OBSC'
#DATA_STRING="ULLI 231101Z 32005MPS 9999 SCT040 20/14 Q1024 R88/090060 NOSIG"
#DATA_STRING="ULLI 271300Z 09006MPS 9999 BKN043CB 20/15 Q1012 R10R/090060 R10L/290050 NOSIG"

############## PARSE
i=0

for field in ${DATA_STRING}; do
  if [[ $i -eq 0 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 1 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 2 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 3 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 4 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 5 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 6 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 7 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 8 ]]; then FIELDS_VALUE[$i]=$field; fi
  if [[ $i -eq 9 ]]; then FIELDS_VALUE[$i]=$field; fi

# Extra data
  # Extra data for WIND
  if [[ (${FIELDS_NAME[$i]} == "VISIBILITI") && ($field == [0-9]*V[0-9]*) ]]; then
    i=$((i-1));
    FIELDS_VALUE[$i]="${FIELDS_VALUE[$i]} $field";
  fi

  # No data for CLOUD
  if [[ (${FIELDS_NAME[$i]} == "VISIBILITI") && ($field == "CAVOK") ]]; then
    FIELDS_VALUE[$i]="$field";
    i=$((i+1));
    FIELDS_VALUE[$i]="";
  fi

  # Extra data for CLOUD
  if [[ (${FIELDS_NAME[$i]} == "TEMPERATURE") && ( ! $field == [0-9]*'/'[0-9]*) ]]; then
    i=$((i-1));
    FIELDS_VALUE[$i]="${FIELDS_VALUE[$i]} $field";
  fi

  # Extra data for ADD_INFO
  if [[ (${FIELDS_NAME[$i]} == "FORECAST_LANDING") && (! $field == "NOSIG") && (! $field == "TEMPO") && (! $field == "BECMG") ]]; then
    i=$((i-1));
    FIELDS_VALUE[$i]="${FIELDS_VALUE[$i]} $field";
  fi

  # Extra data for ADD_INFO2
  if [[ (${FIELDS_NAME[$i]} == "") ]]; then
    FIELDS_VALUE[$i]="";
    i=$((i-1));
    FIELDS_VALUE[$i]="${FIELDS_VALUE[$i]} $field";
  fi

#increment
  i=$((i+1))
done

############## MODIFY

AIRPORT=${FIELDS_VALUE[0]}
AIRPORT="$AIRPORT == LED == Pulkovo"
FIELDS_VALUE[0]=$AIRPORT
unset AIRPORT

TIME=${FIELDS_VALUE[1]}
TIME_DAY="${TIME:0:2}"
TIME_HOUR="${TIME:2:2}"
TIME_HOUR="${TIME_HOUR#0}" # need, because 07 - ok, but 08 - it's hex number
TIME_MIN="${TIME:4:2}"
TIME_GMT="${TIME:6:1}"
TIME_HOUR_LOCAL=$((TIME_HOUR>20?TIME_HOUR-21:TIME_HOUR+3))

TIME="$TIME - $TIME_DAY=day  $TIME_HOUR=hour $TIME_MIN=min $TIME_GMT=GMT0(+3 to get SPB = $TIME_HOUR_LOCAL:$TIME_MIN)"
FIELDS_VALUE[1]=$TIME
unset TIME

WIND=${FIELDS_VALUE[2]}
if [[ ${WIND:0:3} == "VRB" ]]; then
  WIND="$WIND - ${WIND:0:3}-переменный ${WIND:3:2}-скорость MPS-м/c"
else
  WIND="$WIND - ${WIND:0:3}-откуда дует ${WIND:3:2}-скорость MPS-м/c"
fi
WIND_DYNAMIC=$(echo "$WIND" |grep -Poe "[0-9]{3}V[0-9]{3}")
if [[ ! $WIND_DYNAMIC == "" ]]; then WIND="$WIND Меняет направления с ${WIND_DYNAMIC:0:3} до ${WIND_DYNAMIC:4}"; fi

FIELDS_VALUE[2]=$WIND
unset WIND

VISIBILITY=${FIELDS_VALUE[3]}
case $VISIBILITY in
  CAVOK*) VISIBILITY="$VISIBILITY - Ceiling And Visibility OK(условия хорошие)";;
  9999) VISIBILITY="$VISIBILITY"" - Max";;
  [0-9]*) VISIBILITY="$VISIBILITY""m";;
  *) VISIBILITY="$VISIBILITY";;
esac
FIELDS_VALUE[3]=$VISIBILITY
unset VISIBILITY


CLOUD=${FIELDS_VALUE[4]}
if [[ $CLOUD != "" ]]; then

  for CLOUD_PART in ${CLOUD}; do
      CLOUD_PART_TRANSLATE="$CLOUD_PART ="

    # first cloud part must run from -
    if [[ ($(echo "$CLOUD"|grep -Poe "^.*? ?"|sed -e 's/ //g') == "$CLOUD_PART") || ("$CLOUD" == "$CLOUD_PART") ]]; then
      CLOUD_PART_TRANSLATE="- $CLOUD_PART_TRANSLATE"
    fi

    if [[ "${CLOUD_PART:0:1}" == "-" ]]; then
      CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE light"
      CLOUD_PART="${CLOUD_PART:1}"
    fi

    if [[ "${CLOUD_PART:0:1}" == "+" ]]; then
      CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE heavy"
      CLOUD_PART="${CLOUD_PART:1}"
    fi

    case $CLOUD_PART in
      SKC*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE sky is clear";;
      NSC*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE nil significant cloud(без существенной облачности)";;
      FEW*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE few(незначительная 1-2)";;
      SCT*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE scattered(рассеянная или разбросанная 3-4)";;
      BKN*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE broken(значительная или разорванная 5-7)";;
      OVC*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE overcast(сплошная 8)";;
      DZ*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE drizzle(морось)";;
      SG*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE snow grain(комья)" ;;
      PL*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE ice pellets(ледяной дождь)" ;;
      GS*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE small hail(мелкий град или снежная крупа)" ;;
      RASN*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE rain and snow" ;;
      RA*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE rain";;
      SNRA*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE snow and rain" ;;
      SN*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE snow" ;;
      SHSN*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE snow showers" ;;
      SHRA*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE rain showers" ;;
      SHGR*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE hail showers(град)" ;;
      FZRA*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE freezing rain" ;;
      FZDZ*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE freezing drizzle(переохлаждённая морось)" ;;
      TSRA*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE thunderstorm with rain(гроза с дождём)" ;;
      TSGR*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE thunderstorm with hail(гроза с градом)" ;;
      TSGS*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE thunderstorm with small hail(гроза со снежной крупой)" ;;
      TSSN*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE thunderstorm with snow(гроза со снегом)" ;;
      DS*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE duststorm(пыльная буря)" ;;
      SS*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE sandstorm (песчаная буря)" ;;
      FG*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE fog(туман)" ;;
      VCFG*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE fog in vicinity(туман в окрестности)" ;;
      FZFG*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE freezing fog(переохлаждённый туман)" ;;
      MIFG*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE shallow fog(поземный туман)" ;;
      PRFG*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE aerodrome partially covered by fog(аэродром частично покрыт туманом)" ;;
      BCFG*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE fog patches(туман местами)" ;;
      BR*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE mist(дымка)" ;;
      HZ*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE haze(мгла)" ;;
      FU*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE smoke(дым)" ;;
      DRSN*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE low drifting snow(снежный позёмок)" ;;
      DRSA*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE low drifting sand(песчаный позёмок)" ;;
      DRDU*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE low drifting dust(пыльный позёмок)" ;;
      DU*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE dust(пыль в воздухе)" ;;
      BLSN*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE blowing snow(снежная низовая метель)" ;;
      BLDU*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE blowing dust(пыльная низовая метель)" ;;
      SQ*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE squall(шквал)" ;;
      IC*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE ice crystals(ледяные иглы)" ;;
      TS*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE thunderstorm(гроза без осадков)" ;;
      VCTS*) CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE thunderstorm in vicinity(гроза в окрестности)" ;;
      *)    CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE !!! I don't know !!!"
    esac

    # high
    CLOUD_HIGH=$(echo "$CLOUD_PART" |grep -oe "[0-9]*" | sed -e 's/^0*//g')
    if [[ $CLOUD_HIGH -ne "" ]]; then
      CLOUD_PART_TRANSLATE="$CLOUD_PART_TRANSLATE on $CLOUD_HIGH""00ft(*3/10 = $((CLOUD_HIGH*30))m)"
    fi

    CLOUD="$CLOUD $CLOUD_PART_TRANSLATE,"
  done
  CLOUD="${CLOUD:0:((${#CLOUD}-1))}"
  FIELDS_VALUE[4]=$CLOUD

fi
unset CLOUD

TEMPERATURE=${FIELDS_VALUE[5]}
TEMPERATURE="$TEMPERATURE - ${TEMPERATURE:0:2}=temperature ${TEMPERATURE:3}=точка россы"
FIELDS_VALUE[5]=$TEMPERATURE
unset TEMPERATURE

PRESSURE=${FIELDS_VALUE[6]}
PRESSURE="$PRESSURE - 1013==760мм==Normal"
FIELDS_VALUE[6]=$PRESSURE
unset PRESSURE

ADD_INFO=${FIELDS_VALUE[7]}
FIELDS_VALUE[7]=$ADD_INFO
unset ADD_INFO

FORECAST_FOR_LANDING=${FIELDS_VALUE[8]}
case $FORECAST_FOR_LANDING in
  NOSIG*) FORECAST_FOR_LANDING="$FORECAST_FOR_LANDING - No significant change(Без существенных изменений)";;
  BECMG*) FORECAST_FOR_LANDING="$FORECAST_FOR_LANDING - Becoming(Изменение)";;
  *)  FORECAST_FOR_LANDING="$FORECAST_FOR_LANDING - !!! I don't know !!!";;
esac
FIELDS_VALUE[8]=$FORECAST_FOR_LANDING
unset FORECAST_FOR_LANDING



############## OUTPUT
echo "TEXT: $DATA_STRING"

i=0
j=0
for field in ${FIELDS_NAME[*]}; do
  if [[ ${FIELDS_VALUE[$i]} != "" ]]; then
    echo "$((i+1-j))) $field - ${FIELDS_VALUE[$i]}"
  else
    j=$((j+1))
  fi
    i=$((i+1))
done
