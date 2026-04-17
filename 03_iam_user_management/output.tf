
# Output the account ID
output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

# Output user names
output "user_names" {
  value = [for user in aws_iam_user.users : "${user.name}"]
}

# Output user passwords
output "user_passwords" {
  value = {
    for user, profile in aws_iam_user_login_profile.users :
    user => "Password created - user must reset on first login"
  }
  sensitive = true
}