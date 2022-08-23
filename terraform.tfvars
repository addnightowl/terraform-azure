# This overrides what is set in variables.tf
host_os = "linux"
# To override what is set here use terraform console -var="host_os=whateverOS"
# or
# use a tfvar file such as -> terraform console -var-file="filename.tfvars"