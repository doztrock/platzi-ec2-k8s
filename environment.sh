#
# source environment.sh
#

if [ -f "$(pwd)/.terraformrc" ]
then
    export TF_CLI_CONFIG_FILE="$(pwd)/.terraformrc"
else
    echo "Error: .terraformrc not found"
fi
