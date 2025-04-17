#!/bin/bash

read -p "Enter the name: " name
output_file="${name// /_}.txt"

first=1

# Loop through all counties
for cid in {1..95}; do
  echo "🔍 Searching county $cid for '$name'..."

  # Prepare JSON payload for searching parcel data
  json_payload=$(cat <<EOF
{
  "page": 0,
  "dataset": "parcels",
  "text": "$name",
  "token": "QKxacRxFsYjWYQX6dFqR1PaqZrROrfl_JPv_reaVtxDRFG442PaO1sg49LB6_nWOvXeSe2kB7MXj0SxoFvkFu1StEsQ4Dnn9MQMhW9TH1q4.",
  "filterValues": {
    "COUNTY_ID": "$cid",
    "OrderBy": "OWNER,PARCELID"
  }
}
EOF
)

  # Fetch the response
  response=$(curl -s 'https://tnmap.tn.gov/cms/search' \
    -H 'Content-Type: application/json' \
    --data-raw "$json_payload")

  # Extract data array
  items=$(echo "$response" | jq -c 'if type == "array" then .[] else .data[]? end')

  if [[ ! -z "$items" ]]; then
    while IFS= read -r item; do
      if [[ $first -eq 0 ]]; then
        echo "," >> "$output_file"
      fi
      echo "$item" >> "$output_file"
      first=0
    done <<< "$items"
  fi

  echo "Formatting file..."
  echo "--------------------------------------------"
done

# Replace double quotes with single quotes for readability
sed -i "s/\"/'/g" "$output_file"

echo "✅ Done. Results written to: $output_file"

# Join all single-quoted GISLINKs into a comma-separated string
formatted_gislinks=$(paste -sd, - < "$output_file")
# Clean up triple or leading/trailing commas
formatted_gislinks=$(echo "$formatted_gislinks" | sed 's/,,*/,/g' | sed 's/^,//;s/,$//')

echo "🔗 GISLINKs: $formatted_gislinks"
echo "📡 Running curl to get parcel geometry..."

# Fetch geometry data using GISLINKs
curl 'https://tnmap.tn.gov/arcgis/rest/services/CADASTRAL/STATEWIDE_PARCELS_WEB_MERCATOR/MapServer/0/query' \
  -H 'Origin: https://tnmap.tn.gov' \
  -H 'Referer: https://tnmap.tn.gov/assessment/' \
  -H 'User-Agent: Mozilla/5.0' \
  -H 'Accept: */*' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'Connection: keep-alive' \
  -b 'AGS_ROLES="em53Lpm4pzMuX+SWVW/tDre3kQh2YgZI2UVZuR5jh40="; _ga=GA1.1.2007503624.1744761481; assessmentDisclaimerTimeout=1747353521343; _ga_6NRV0ZCXR3=GS1.1.1744761481.1.1.1744761753.0.0.0' \
  --form "outSR=4326" \
  --form "geometryType=esriGeometryEnvelope" \
  --form "outFields=*" \
  --form "where=GISLINK in ($formatted_gislinks)" \
  --form "f=geojson" \
  --form "token=QKxacRxFsYjWYQX6dFqR1PaqZrROrfl_JPv_reaVtxDRFG442PaO1sg49LB6_nWOvXeSe2kB7MXj0SxoFvkFu1StEsQ4Dnn9MQMhW9TH1q4." \
  -o "${name// /_}.data"

# Format GeoJSON data to keep only required properties
jq '[.features[] | { 
  GISLINK: .properties.GISLINK,
  COUNTY_ID: .properties.COUNTY_ID,
  PARCEL_TYPE: .properties.PARCEL_TYPE,
  CALC_ACRE: .properties.CALC_ACRE,
  PARCELID: .properties.PARCELID,
  FILE_TYPE: .properties.FILE_TYPE,
  CONUM: .properties.CONUM,
  CMAP: .properties.CMAP,
  GP: .properties.GP,
  PARCEL: .properties.PARCEL,
  ADDRESS: .properties.ADDRESS,
  CITY: .properties.CITY,
  DEEDAC: .properties.DEEDAC,
  CALCAC: .properties.CALCAC,
  OWNER: .properties.OWNER,
  OWNER2: .properties.OWNER2,
  LASTUPDATE: .properties.LASTUPDATE,
  SUBDIV: .properties.SUBDIV,
  LOT: .properties.LOT,
  "Shape.STArea()": .properties["Shape.STArea()"],
  "Shape.STLength()": .properties["Shape.STLength()"],
  OBJECTID_1: .properties.OBJECTID_1,
  OBJECTID: .properties.OBJECTID,
  "Shape_STArea__": .properties["Shape_STArea__"],
  "Shape_STLength__": .properties["Shape_STLength__"],
  FULL_SEARCH_FIELD: .properties.FULL_SEARCH_FIELD
}]' "${name// /_}.data" > "${name// /_}_filtered.data"
#rm "$output_file"
#rm "${name// /_}.data"
echo "✅ GeoJSON data filtered and written to: ${name// /_}_filtered.data"
 
