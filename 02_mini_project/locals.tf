locals {
  common_tags = {
    Environment = var.environment
    Project     = "VPC-Peering"
  }

  primary_user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx

    echo "<h1>Primary VPC - ${var.primary_region}</h1>" > /var/www/html/index.nginx-debian.html
    echo "<p>Private IP: $(hostname -I)</p>" >> /var/www/html/index.nginx-debian.html
  EOF

  secondary_user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx

    echo "<h1>Secondary VPC - ${var.secondary_region}</h1>" > /var/www/html/index.nginx-debian.html
    echo "<p>Private IP: $(hostname -I)</p>" >> /var/www/html/index.nginx-debian.html
  EOF
}