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
    for user in aws_iam_user.users : user.name if contains(keys(user.tags), "JobTitle") && can(regex("Manager|CEO", user.tags.JobTitle))
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

# NEXT STEP : 1. Add IAM Policies to Groups
# Education --> ReadOnlyAccess
# Managers --> FullAccess
# Engineers --> EC2 / Dev Access

# Education group role access
resource "aws_iam_group_policy_attachment" "education_readonly" {
  group = aws_iam_group.education.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Manager group role access
resource "aws_iam_group_policy_attachment" "managers_admin" {
  group = aws_iam_group.managers.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Engineer Group Access
resource "aws_iam_group_policy_attachment" "engineers_ec2" {
  group = aws_iam_group.engineers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}