awsve() {
  aws-vault exec $@
}

upload() {
  aws-vault exec jc aws s3 cp --acl public-read ${@:2} $1 s3://blit-files
}
