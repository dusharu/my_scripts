#!/bin/bash
################################################################################
#                                                                              #
#                          Simple ping on TCP                                  #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2020.10.10 #
################################################################################
export PATH="$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

#################### VAR
HOST=""
IP=""
PORT=""
TCP_WAIT=500
TIME=""
COUNT=""
INTERVAL=1
LOG=""

#### EXIT_CODE
EXIT_HELP=200
EXIT_UNEXPECTED_PARAMETR=201
EXIT_INVALID_HOST=202
EXIT_INVALID_PORT=203
EXIT_INVALID_TCP_WAIT=204
EXIT_INVALID_INTERVAL=205
EXIT_CANT_WRITE_LOG=206



#################### Function
function help (){
  echo "===== HELP ====="
  echo "$0 [OPTIONS] <HOST|IP> <PORT>"
  echo "OPTIONS:"
  echo "  -h, --help - print help and exit."
  echo "  -w <ms>, --wait <ms> - time to wait for a response, in milisecond."
  echo "  -i <sec>, --interval <sec> - wait interval seconds between sending each packet."
  echo "  -t <sec>, --time <sec> - stop after time, in second."
  echo "  -c <num>, --count <num> - stop after sending count pkg."
  echo "  -l <file>, --log <file> - write to log-file."
}


#################### MAIN
##### Get VARS
while [[ $# -gt 0 ]]; do
  case $1 in
    -h) help; exit "$EXIT_HELP" ;;
    --help) help; exit "$EXIT_HELP" ;;
    -w) shift; TCP_WAIT="$1" ;;
    --wait) shift; TCP_WAIT="$1" ;;
    -i) shift; INTERVAL="$1" ;;
    --interval) shift; INTERVAL="$1" ;;
    -t) shift; TIME="$1" ;;
    --time) shift; TIME="$1" ;;
    -c) shift; COUNT="$1" ;;
    --count) shift; COUNT="$1" ;;
    -l) shift; LOG="$1" ;;
    --log) shift; LOG="$1" ;;
    *)
      if [[ $HOST == "" ]]; then
        HOST="$1"
      elif [[ $PORT = "" ]]; then
        PORT="$1"
      else
        echo "ERROR. Unexpect parametr: $1"
        echo
        help
        exit "$EXIT_UNEXPECTED_PARAMETR"
      fi
    ;;
  esac
  shift
done


##### Check VARS
if [[ $HOST =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  IP="$HOST"
else
  IP="$(getent ahostsv4 "$HOST" | grep -m 1 STREAM |cut -d " " -f1 2>/dev/null)"
  HOST="$HOST($IP)"
  if [[ ! $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "Invalid HOST: ${HOST}\n"
    help
    exit "$EXIT_INVALID_HOST"
  fi
fi

if [[ "$PORT" -le 0 || "$PORT" -gt 65535 ]]; then
  echo -e "Invalid PORT: ${PORT}\n"
  help
  exit "$EXIT_INVALID_PORT"
fi

if [[ "$TCP_WAIT" -le 0 ]]; then
  echo -e "Invalid TCP_WAIT: ${TCP_WAIT}\n"
  help
  exit "$EXIT_INVALID_TCP_WAIT"
fi

if [[ "$INTERVAL" -le 0 ]]; then
  echo -e "Invalid TCP_INTERVAL: ${INTERVAL}\n"
  help
  exit "$EXIT_INVALID_INTERVAL"
fi

if [[ "$TIME" != "" ]] && [[ "$TIME" -le 0 ]]; then
  echo -e "Invalid TIME: ${TIME}\n"
  help
  exit "$EXIT_INVALID_TIME"
fi

if [[ "$COUNT" -le 0 ]] && [[ "$COUNT" != "" ]]; then
  echo -e "Invalid COUNT: ${COUNT}\n"
  help
  exit "$EXIT_INVALID_COUNT"
fi

if [[ "$LOG" != "" ]]; then
  # try to create new file
  if ! touch "$LOG" >/dev/null 2>&1 ; then
    echo -e "Can't write LOG to $LOG"
    exit "$EXIT_CANT_WRITE_LOG"
  fi
  # check that exist log-fie writable
  if [[ ! -w "$LOG" ]]; then
    echo -e "Can't write LOG to $LOG"
    exit "$EXIT_CANT_WRITE_LOG"
  fi
  # clear log
  true > "$LOG"
fi

## DEBUG:
#echo "====== Get Vars: ===="
#echo "HOST: $HOST"
#echo "IP: $IP"
#echo "PORT: $PORT"
#echo "TCP_WAIT: ${TCP_WAIT}ms = $(perl -E "say $TCP_WAIT/1000")s"
#echo "INTERVAL: $INTERVAL"
#echo "TIME: $TIME"
#echo "COUNT: $COUNT"
#echo "LOG: $LOG"
#echo

##### TCP_PING
NUM=1
START="$(date +%s)"
TCP_WAIT="$(perl -E "say $TCP_WAIT/1000")"

while { [[ "$TIME" == "" ]] || [[ "$TIME" -ge $(( $(date +%s) - START)) ]] ;} &&\
      { [[ "$COUNT" == "" ]] || [[ "$COUNT" -ge $NUM ]] ;}; do

  # time run timeout as fork
  # timeout run bash as fork
  # bash sent TCP pkg
  # all this forks add 1-5ms error to TCP_TIME
  # and we get strange output when TCP_WAIT=10ms(0.1s)
  # 2020-10-11_04-56-14: google.com(173.194.73.138):80 - 0m0.014s - OK

  if TCP_TIME="$(time ( timeout "$TCP_WAIT" bash -c "echo > /dev/tcp/$IP/$PORT" &>/dev/null ) 2>&1 )" ; then
    if [[ $LOG == "" ]]; then
      echo "$(date +%F_%H-%M-%S): $HOST:$PORT - $(echo "$TCP_TIME" | grep real -m1 | awk '{print $2}') - OK"
    else
      echo "$(date +%F_%H-%M-%S): $HOST:$PORT - $(echo "$TCP_TIME" | grep real -m1 | awk '{print $2}') - OK" | tee -a "$LOG"
    fi
  else
    if [[ $LOG == "" ]]; then
      echo "$(date +%F_%H-%M-%S): $HOST:$PORT -  - FALSE"
    else
      echo "$(date +%F_%H-%M-%S): $HOST:$PORT -  - FALSE" | tee -a "$LOG"
    fi
  fi

  sleep "$INTERVAL"
  ((NUM++))
done
