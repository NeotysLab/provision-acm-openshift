#!/bin/bash
CREDS=./creds.json
cp ./creds.sav $CREDS

echo Please enter the credentials as requested below:  
read -p "Dynatrace Tenant: (default=$DTENV)" DTENVC
read -p "Dynatrace API Token: (default=$DTENV) " DTAPIC
read -p "Dynatrace PaaS Token: (default=$DTAPI) " DTPAAST
read -p "github User Name: " GITU 
read -p "github Personal Access Token: " GITAT
read -p "github User Email: " GITE
read -p "github Organization: " GITO
read -p "NeoLoadWeb Api KEY: " NLWEBAPI
echo ""

if [[ $DTENV = '' ]]
then 
  DTENV=$DTENVC
fi

if [[ $DTAPI = '' ]]
then 
  DTAPI=$DTAPIC
fi

echo ""
echo "Please confirm all are correct:"
echo "Dynatrace Tenant: $DTENV.live.dynatrace.com"
echo "Dynatrace API Token: $DTAPI"
echo "Dynatrace AccountID : $DTENV"
echo "Dynatrace PaaS Token: $DTPAAST"
echo "github User Name: $GITU"
echo "github Personal Access Token: $GITAT"
echo "github User Email: $GITE"
echo "github Organization: $GITO"
echo "NeoLoad Web API Key :$NLWEBAPI"
read -p "Is this all correct?" -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
  sed -i 's/DYNATRACE_TENANT_PLACEHOLDER/'"$DTENV".live.dynatrace.com'/' $CREDS
  sed -i 's/DYNATRACE_API_TOKEN/'"$DTAPI"'/' $CREDS
  sed -i 's/DYNATRACE_PAAS_TOKEN/'"$DTPAAST"'/' $CREDS
  sed -i 's/DT_ACCOUNTID_PLACEHOLDER/'"$DTENV"'/' $CREDS
  sed -i 's/GITHUB_USER_NAME_PLACEHOLDER/'"$GITU"'/' $CREDS
  sed -i 's/PERSONAL_ACCESS_TOKEN_PLACEHOLDER/'"$GITAT"'/' $CREDS
  sed -i 's/GITHUB_USER_EMAIL_PLACEHOLDER/'"$GITE"'/' $CREDS
  sed -i 's/GITHUB_ORG_PLACEHOLDER/'"$GITO"'/' $CREDS
  sed -i 's/NL_WEB_API_KEY_PLACEHOLDER/'"$NLWEBAPI"'/' $CREDS


fi
cat $CREDS
echo ""
echo "the creds file can be found here:" $CREDS
echo ""