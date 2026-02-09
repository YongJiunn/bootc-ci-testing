#!/bin/bash
set -euo pipefail

YAML="tailoring.yaml"
OUTPUT_FILE="../system_files/usr/share/ssg_cs9_ds_tailoring_generated.xml"
TEMPLATE="../tailoring_script/ssg_cs9_ds_tailoring_template.xml"

# Static metadata
BENCHMARK_HREF="C:/Users/souluseless/Downloads/ssg-cs9-ds.xml"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S")
PROFILE_ID="xccdf_org.ssgproject.content_profile_cis_customized"
PROFILE_VERSION="2.0.0"
PROFILE_TITLE="CIS Red Hat Enterprise Linux 9 Benchmark for Level 2 - Server [CUSTOMIZED]"
PROFILE_DESCRIPTION="This profile defines a baseline that aligns to the 'Level 2 - Server' configuration..."

SELECTIONS=""
SET_VALUES=""
REFINE_VALUES=""

# --- Generate selections from .rule
mapfile -t rule_entries < <(yq e '.rule | to_entries | .[] | "\(.key)=\(.value)"' "$YAML")

SELECTIONS=""
for entry in "${rule_entries[@]}"; do
    idref="${entry%%=*}"
    flag="${entry#*=}"
    SELECTIONS+="<xccdf:select idref=\"$idref\" selected=\"$flag\"/>"$'\n'
done

# --- Generate set-value
mapfile -t setvals < <(yq e '.set-value | to_entries | .[] | "\(.key)=\(.value)"' "$YAML")

SET_VALUES=""
# if setvals is not empty, then generate set-value
if [ "${#setvals[@]}" -gt 0 ]; then
for sv in "${setvals[@]}"; do
    key="${sv%%=*}"
    value="${sv#*=}"
    SET_VALUES+="<xccdf:set-value idref=\"$key\">$value</xccdf:set-value>"$'\n'
done
fi

# --- Generate refine-value
mapfile -t refvals < <(yq e '.refine-value | to_entries | .[] | "\(.key)=\(.value)"' "$YAML")

REFINE_VALUES=""
if [ "${#refvals[@]}" -gt 0 ]; then
for rv in "${refvals[@]}"; do
    key="${rv%%=*}"
    selector="${rv#*=}"
    REFINE_VALUES+="<xccdf:refine-value idref=\"$key\" selector=\"$selector\"/>"$'\n'
done
fi

awk \
    -v benchmark_href="$BENCHMARK_HREF" \
    -v timestamp="$TIMESTAMP" \
    -v profile_id="$PROFILE_ID" \
    -v profile_version="$PROFILE_VERSION" \
    -v profile_title="$PROFILE_TITLE" \
    -v profile_description="$PROFILE_DESCRIPTION" \
    -v selections="$SELECTIONS" \
    -v set_values="$SET_VALUES" \
    -v refine_values="$REFINE_VALUES" '
{
    gsub("{benchmark_href}", benchmark_href);
    gsub("{timestamp}", timestamp);
    gsub("{profile_id}", profile_id);
    gsub("{profile_version}", profile_version);
    gsub("{profile_title}", profile_title);
    gsub("{profile_description}", profile_description);
    gsub("{selections}", selections);
    gsub("{set_values}", set_values);
    gsub("{refine_values}", refine_values);
    print;
}' "$TEMPLATE" > "$OUTPUT_FILE"

echo "Generated: $OUTPUT_FILE"