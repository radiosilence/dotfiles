# Google Cloud Platform configuration
command -v gcloud >/dev/null || return

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
