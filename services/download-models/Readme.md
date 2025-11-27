## Build
```bash
gcloud builds submit \
  --config cloudbuild.yaml \
  --substitutions _SERVICE_NAME=gcs-download-server,_REGION=us-central1,_GCS_BUCKET=your-bucket-name,_GCS_PREFIX=path/to/folder/
```