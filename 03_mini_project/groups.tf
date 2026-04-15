# Create IAM Groups
resource "aws_iam_group" "education" {
  name = "Education"
  path = "/groups/"
}

resource "aws_iam_group" "managers" {
  name = "Managers"
  path = "/groups/"
}

resource "aws_iam_group" "engineers" {
  name = "Engineers"
  path = "/groups/"
}

resource "aws_iam_group" "admins" {
  name = "Admins"
  path = "/groups/"
}

# Add users to the Education group
resource "aws_iam_group_membership" "education_members" {
  name  = "education-group-membership"
  group = aws_iam_group.education.name

  users = [
    for user in aws_iam_user.users : user.name if user.tags.Department == "Education"
  ]
}

# Add users to the Managers group
resource "aws_iam_group_membership" "managers_members" {
  name  = "managers-group-membership"
  group = aws_iam_group.managers.name

  users = [
    # for user in aws_iam_user.users : user.name if contains(keys(user.tags), "JobTitle") && can(regex("Manager|CEO", user.tags.JobTitle))
    for user in aws_iam_users : user.name if user.tags.AccessLevel == "admin"
  ]
}

# Add users to the Engineers group
resource "aws_iam_group_membership" "engineers_members" {
  name  = "engineers-group-membership"
  group = aws_iam_group.engineers.name

  users = [
    for user in aws_iam_user.users : user.name if user.tags.Department == "Engineering"
  ]
}

# Add users to the Admins group
resource "aws_iam_group_membership" "admin_members" {
  name = "admin-group-membership"
  group = aws_iam_group.admins.name

  users = [
    for user in aws_iam_user.users : user.name
    if user.tags.AccessLevel == "admin"
  ]
}

# NEXT STEP : 1. Add IAM Policies to Groups
# Education --> ReadOnlyAccess
# Managers --> FullAccess
# Engineers --> EC2 / Dev Access

# Attach policies to Education group
resource "aws_iam_group_policy_attachment" "education_readonly" {
  group = aws_iam_group.education.name
  policy_arn = aws_iam_policy.require_mfa.arn
}

# Attach policies to Manager group
resource "aws_iam_group_policy_attachment" "managers_admin" {
  group = aws_iam_group.managers.name
  policy_arn = aws_iam_policy.require_mfa.arn
}

# Attach policies to Engineer group
resource "aws_iam_group_policy_attachment" "engineers_ec2" {
  group = aws_iam_group.engineers.name
  policy_arn = aws_iam_policy.require_mfa.arn
}

# Attach policies to admin group
resource "aws_iam_group_policy_attachment" "admins_policy" {
  group = aws_iam_group.admins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}