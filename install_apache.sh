## stole from https://www.bogotobogo.com/DevOps/Terraform/Terraform-terraform-userdata.php
#! /bin/bash
sudo apt-get -y update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
