awsve() {
  aws-vault exec $@
}

upload() {
  AWS_PROFILE=jc
  aws s3 cp ${@:2} $1 s3://blit-files
  echo https://your-cloudfront-domain.whatever/$1 | pbcopy
}
