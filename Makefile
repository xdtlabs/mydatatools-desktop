# ==============================================================================
# Makefile for building and deploying a Cloud Run service via Cloud Build
#
# Usage:
#   1. make init       # Sets the required gcloud project ID
#   2. make deploy     # Builds and deploys the GCS file downloader service
#   3. make deploy-all # FUTURE: Deploys multiple services iteratively
# ==============================================================================

# --- Global Configuration (Goal 1: Set Project ID) ---
PROJECT_ID = mydata-tools

# --- Service Configuration for GCS Downloader ---
SERVICE_NAME = gcs-file-downloader
REGION = us-central1
IMAGE_REPO = cloud-run-source-deploy # <- This is the Artifact Registry Repository Name


# !! IMPORTANT: CUSTOMIZE THESE VALUES !!
GCS_BUCKET = mydata-tools_downloads # e.g., my-secure-storage-bucket
GCS_PREFIX = local-llm-models/ # e.g., data/client-uploads/ (must include trailing slash)

# --- Targets ---


help:
	@echo "Available targets:"
	@echo "  init                  - Set gcloud project ID and configure environment"
	@echo "  build-aichat          - Build the aichat.zip package"
	@echo "  deploy-download-service - Build and deploy the GCS file downloader service"
	@echo "  clean                 - Remove generated build artifacts"


# Default target runs init and deploy
all: init deploy-download-service

# Project Initialization Target (Goal 1)
.PHONY: init
init:
	@echo "--- 🛠️  Setting gcloud project ID to $(PROJECT_ID) ---"
	gcloud auth application-default set-quota-project $(PROJECT_ID)
	gcloud config set project $(PROJECT_ID)
	@echo "Project configuration complete. Service is ready to deploy."


# Build the aichat.zip package
build-aichat-macos:
	@echo "Building aichat-macos.zip..."
	cd client/assets/python/aichat && python -m pip install -r requirements.txt && python -m PyInstaller main.spec --clean --noconfirm && cd dist && zip -r ../../../../app/aichat-macos.zip aichat
	@echo "Build complete: app/aichat-macos.zip"


# Deployment Single Service (Current Service)
# This target uses the cloudbuild.yaml in the root directory.
.PHONY: deploy-download-service
download-service-deploy: init grant-permissions
	@echo "--- 🚀 Deploying $(SERVICE_NAME) to Cloud Run in $(REGION) ---"
	@echo "Source Bucket: $(GCS_BUCKET) | Prefix: $(GCS_PREFIX)"
	# EXECUTES GCLOUD BUILD SUBMIT COMMAND
	cd services/download-models && gcloud builds submit . \
		--config cloudbuild.yaml \
		--region=$(REGION) \
		--substitutions _SERVICE_NAME=$(SERVICE_NAME),_REGION=$(REGION),_GCS_BUCKET=$(GCS_BUCKET),_GCS_FOLDER_PREFIX=$(GCS_PREFIX),_REPO_NAME=$(IMAGE_REPO)
	@echo "--- ✅ Deployment initiated. Check Cloud Build and Cloud Run logs. ---"


# Grant Permissions Target
.PHONY: download-service-permissions
download-service-permissions:
	@echo "--- 🔐 Granting 'Service Account Token Creator' role to the default Compute service account ---"
	PROJECT_NUMBER=$$(gcloud projects describe $(PROJECT_ID) --format='value(projectNumber)') && \
	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member="serviceAccount:$${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
		--role="roles/iam.serviceAccountTokenCreator" \
		--condition=None
	@echo "--- ✅ Permissions granted to default Compute service account. ---"


# 4. Cleanup Target
.PHONY: clean
clean:
	@echo "--- Cleaning up local temporary files ---"
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -r {} +
	@echo "Clean complete."

