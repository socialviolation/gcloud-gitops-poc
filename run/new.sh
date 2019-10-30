#!/usr/bin/env bash

set -e

SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
BASEPATH="$SCRIPT_PATH/.."

# PROJECT_ID=$(gcloud config get-value project)
DEFAULT_REGION=australia-southeast1
DEFAULT_ZONE=australia-southeast1-b
PROJECT_APIS=(
    cloudbuild.googleapis.com 
    compute.googleapis.com 
    sourcerepo.googleapis.com
)

source "${SCRIPT_PATH}/lib.sh"

gen_id() {
    echo "$1-$((1 + RANDOM % 900000))" | tr '[:upper:]' '[:lower:]' | sed -e 's/ /-/g'
}


project_create_basic() {
    echo -n "Enter name for project: "
    read -r PROJECT_NAME

    PROJECT_ID=$(gen_id "$PROJECT_NAME")

    echo -n "Enter ID for project [$PROJECT_ID]: "
    read -r PROJECT_ID_OVERRIDE

    if [ ! -z $PROJECT_ID_OVERRIDE ]
    then
        PROJECT_ID=$(gen_id "$PROJECT_ID_OVERRIDE")
    fi

    echo "creating project [$PROJECT_NAME - $PROJECT_ID]"
    yes_no "proceed? "

    gcloud projects create "$PROJECT_ID" \
        --name="$PROJECT_NAME" \
        --set-as-default
    
    gcloud compute project-info add-metadata \
        --metadata google-compute-default-region=${DEFAULT_REGION},google-compute-default-zone=${DEFAULT_ZONE}

    select_billing

    gcloud beta billing projects link ${PROJECT_ID} \
        --billing-account ${KIX_BILLING_ID}

    echo "Enabling APIs"
    gcloud services enable ${PROJECT_APIS[@]}

    echo "Creating bucket for tf state"
    gsutil mb -c standard -l ${DEFAULT_REGION} \
        gs://${PROJECT_ID}-tfstate

    gsutil versioning set on gs://${PROJECT_ID}-tfstate

    CLOUDBUILD_SA="$(gcloud projects describe ${PROJECT_ID} --format 'value(projectNumber)')@cloudbuild.gserviceaccount.com"
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member serviceAccount:$CLOUDBUILD_SA --role roles/editor
}

make_project_source() {
    REPO_NAME=${PROJECT_ID}-tf
    REPO_DIR=${BASEPATH}/cloud-source/${REPO_NAME}

    echo "repo name: ${REPO_NAME}"
    echo "repo dir: ${REPO_DIR}"

    gcloud source repos create ${REPO_NAME}
    
    if [ ! -d ${REPO_DIR} ]
    then
        mkdir -p ${REPO_DIR}
        mkdir -p ${REPO_DIR}/modules
        cp -a ${BASEPATH}/templates/tf-cloudbuild-gitops/modules/* ${REPO_DIR}/modules/
        cp ${BASEPATH}/templates/tf-cloudbuild-gitops/cloudbuild.yaml ${REPO_DIR}
        cp ${BASEPATH}/templates/tf-cloudbuild-gitops/.gitignore ${REPO_DIR}
    fi

    {
        cd ${REPO_DIR}
        git init
        git config credential.helper gcloud.sh
        git add .
        git commit -am "Initial commit - adding modules"
        git remote add google \
            https://source.developers.google.com/p/${PROJECT_ID}/r/${REPO_NAME}
        git push --all google

        gcloud beta builds triggers create cloud-source-repositories \
            --repo=${REPO_NAME} \
            --description="Automated Infrastructure builder for ${REPO_NAME}" \
            --branch-pattern=.* \
            --build-config=cloudbuild.yaml
    }

    generate_environment
}

generate_environment() {
    echo "generate_environment ${REPO_DIR}"
    PROJECT_ENV="dev"
    echo -n "Enter environment for project [$PROJECT_ENV]: "
    read -r PROJECT_ENV_O
    if [ ! -z $PROJECT_ENV_O ]
    then
        PROJECT_ENV = $PROJECT_ENV_O
    fi

    ENVIRONMENT_DIR=${REPO_DIR}/environments/${PROJECT_ENV}
    if [ ! -d ${ENVIRONMENT_DIR} ]
    then
        mkdir -p ${ENVIRONMENT_DIR}
        cp -r ${BASEPATH}/templates/tf-cloudbuild-gitops/environments/dev/* ${ENVIRONMENT_DIR}/
        sed -i '' 's/PROJECT_ID/'${PROJECT_ID}'/g' ${ENVIRONMENT_DIR}/terraform.tfvars
        sed -i '' 's/PROJECT_ID/'${PROJECT_ID}'/g' ${ENVIRONMENT_DIR}/backend.tf
        sed -i '' 's/PROJECT_ENV/'${PROJECT_ENV}'/g' ${ENVIRONMENT_DIR}/backend.tf
    else
        echo "environment already exists."
    fi
    {
        cd ${REPO_DIR}
        git init
        git add .
        git commit -am "Generated Environment: ${PROJECT_ENV}"
        git push --all google
    }
}

project_create_organisation() {
    echo "TODO"
    exit 1
}

project_create_basic
