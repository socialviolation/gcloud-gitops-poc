function do_exit {
  exit "$1"
}

function yes_no {
  local YES=
  echo -n -e "$1 [yes] > "
  read -r YES

  if [ "${YES}" != "yes" ]; then
    echo "Interrupting..."
    do_exit 0
  fi
}

function select_org {
# org array: [{id,displayName}]
  local ORG_ARRAY=($1)
  local ORG_COUNT="${#ORG_ARRAY[@]}"
  local ORG_IDX=
  ORG_NAME=
  ORG_ID=

  if [ "${ORG_COUNT}" -eq 0 ]; then
    echo "Could not find any organization"
    return 1
  fi

# Select and return first organisation, if only 1 available
  if [ "${ORG_COUNT}" -eq 1 ]; then
    IFS=',' read -r -a chosenOrg<<< "${ORG_ARRAY[0]}"
    export KIX_ORG_NAME=${chosenOrg[0]}
    export KIX_ORG_ID=${chosenOrg[1]}
    
    return 0
  fi

# Print organisations
  echo "Select your organisation from the following list:"
  for i in ${!ORG_ARRAY[@]}; do 
    IFS=',' read -r -a orgInfo<<< "${ORG_ARRAY[$i]}"
    echo -e "$((${i} + 1)). ${orgInfo[0]} - ${orgInfo[1]}"
  done

# get option
  echo -n "[1-${ORG_COUNT}] > "
  read -r ORG_IDX

# validate input
  if ! [ "${ORG_IDX}" -ge 1 ] || ! [ "${ORG_IDX}" -le "${ORG_COUNT}" ]; then
    echo "Invalid org index, exiting..."
    return 2
  fi

# select org index values
  ORG_IDX=$((${ORG_IDX} - 1))
  IFS=',' read -r -a chosenOrg<<< "${ORG_ARRAY[${ORG_IDX}]}"
  export KIX_ORG_NAME=${chosenOrg[0]}
  export KIX_ORG_ID=${chosenOrg[1]}

  return 0
}

function select_billing {
# billing array: [{id,display-name}]
  echo "hey there"
  GQ_BILLING_RAW=$(gcloud beta billing accounts list --format="csv[no-heading](name,displayName.sub(' ', '-'))")
  local BILLING_ARRAY=$GQ_BILLING_RAW
  local BILLING_COUNT="${#BILLING_ARRAY[@]}"
  local BILLING_IDX=
  BILLING_NAME=
  BILLING_ID=

  if [ "${BILLING_COUNT}" -eq 0 ]; then
    echo "Could not find any billing account"
    return 1
  fi

# Select and return first billing account, if only one available
  if [ "${BILLING_COUNT}" -eq 1 ]; then
    IFS=',' read -r -a chosenAccount<<< "${BILLING_ARRAY[0]}"
    export KIX_BILLING_ID=${chosenAccount[0]}
    export KIX_BILLING_NAME=${chosenAccount[1]}
    echo "Defaulting to only option Billing Account: ${KIX_BILLING_NAME}"

    return 0
  fi

# Print billing accounts
  echo "Select your desired billing account from the following list:"
  for i in ${!BILLING_ARRAY[@]}; do 
    IFS=',' read -r -a binfo<<< "${BILLING_ARRAY[$i]}"
    echo -e "$((${i} + 1)). ${binfo[0]} - ${binfo[1]}"
  done

# Get option
  echo -n "[1-${BILLING_COUNT}] > "
  read -r BILLING_IDX

# Verify input
  if ! [ "${BILLING_IDX}" -ge 1 ] || ! [ "${BILLING_IDX}" -le "${BILLING_COUNT}" ]; then
    echo "Invalid billing index, exiting..."
    return 2
  fi

# select billing index values
  BILLING_IDX=$((${BILLING_IDX} - 1))
  IFS=',' read -r -a chosenAccount<<< "${BILLING_ARRAY[${BILLING_IDX}]}"
  export KIX_BILLING_ID=${chosenAccount[0]}
  export KIX_BILLING_NAME=${chosenAccount[1]}

  return 0
}
