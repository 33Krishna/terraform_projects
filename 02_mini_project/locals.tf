
# locals {
#   # User data template for Primary instance
#   primary_user_data = <<-EOF
#     #!/bin/bash
#     apt-get update -y
#     apt-get install -y apache2
#     systemctl start apache2
#     systemctl enable apache2
#     echo "<h1>Primary VPC Instance On ${var.primary_region}</h1>" > /var/www/html/index.html
#     echo "<p>Private IP: $(hostname -I)</p>" >> /var/www/html/index.html
#   EOF

#   # User data template for Secondary instance
#   secondary_user_data = <<-EOF
#     #!/bin/bash
#     apt-get update -y
#     apt-get install -y apache2
#     systemctl start apache2
#     systemctl enable apache2
#     echo "<h1>Secondary VPC Instance On ${var.secondary_region}</h1>" > /var/www/html/index.html
#     echo "<p>Private IP: $(hostname -I)</p>" >> /var/www/html/index.html
#   EOF
# }

locals {
  # User data template for Primary instance (NGINX)
  primary_user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx

    echo "<h1>Primary VPC Instance On ${var.primary_region}</h1>" > /var/www/html/index.nginx-debian.html
    echo "<p>Private IP: $(hostname -I)</p>" >> /var/www/html/index.nginx-debian.html
  EOF

  # User data template for Secondary instance (NGINX)
  secondary_user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx

    echo "<h1>Secondary VPC Instance On ${var.secondary_region}</h1>" > /var/www/html/index.nginx-debian.html
    echo "<p>Private IP: $(hostname -I)</p>" >> /var/www/html/index.nginx-debian.html
  EOF
}