LOCALAI=https://ai.dc
if [ "$1" == "search" ] ; then
  curl ${LOCALAI}/models/available | jq ".[] | select(.name | contains(\"${2}\")) | .name"
elif [ "$1" == "apply" ] ; then
  STATUS_URL=$(curl -q $LOCALAI/models/apply -H "Content-Type: application/json" -d "{ \"id\": \"${2}\" }" | jq -r .status)
  STATUS=$(curl -q $STATUS_URL | jq -r .message)
  while [ "$STATUS" != "completed" ] ; do
    STATUS=$(curl -q $STATUS_URL | jq -r .message)
    echo $STATUS
    sleep 5
  done
elif [ "$1" == "list" ] ; then
  curl -q $LOCALAI/models | jq .
fi
