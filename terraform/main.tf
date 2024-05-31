##Create a S3 bucket 
resource "aws_s3_bucket" "yt-de-data-lake" {
  bucket_prefix = var.bucket_prefix
  force_destroy = true
}

##Enable server-side encryption(SSE-S3)
resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.yt-de-data-lake.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}


# IAM role for EC2 to connect to AWS Redshift, S3, & EMR
resource "aws_iam_role" "yt_de_ec2_iam_role" {
  name = "yt_de_ec2_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess", "arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2", "arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess"]
}

resource "aws_iam_instance_profile" "yt_de_ec2_iam_role_instance_profile" {
  name = "yt_de_ec2_iam_role_instance_profile"
  role = aws_iam_role.yt_de_ec2_iam_role.name
}

# IAM role for Redshift to be able to read data from S3 via Spectrum
resource "aws_iam_role" "yt_de_redshift_iam_role" {
  name = "yt_de_redshift_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess", "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"]
}

# Create security group for access to EC2 from your Anywhere
resource "aws_security_group" "yt_de_security_group" {
  name        = "yt_de_security_group"
  description = "Security group to allow inbound SCP & outbound 8080 (Airflow) connections"

  ingress {
    description = "Inbound SCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    # Inbound rule for Airflow (port 8080)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]# Allow access from anywhere (for   testing)
    description = "Allow Airflow web server access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "yt_de_security_group"
  }
}






#Set up EMR
resource "aws_emr_cluster" "yt_de_emr_cluster" {
  name                   = "yt_de_emr_cluster"
  release_label          = "emr-6.2.0"
  applications           = ["Spark", "Hadoop"]
  scale_down_behavior    = "TERMINATE_AT_TASK_COMPLETION"
  service_role           = "EMR_DefaultRole"
  termination_protection = false
  auto_termination_policy {
    idle_timeout = var.auto_termination_timeoff
  }

  ec2_attributes {
    instance_profile = aws_iam_instance_profile.yt_de_ec2_iam_role_instance_profile.id
  }


  master_instance_group {
    instance_type  = var.instance_type
    instance_count = 1
    name           = "Master - 1"

    ebs_config {
      size                 = 32
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }

  core_instance_group {
    instance_type  = var.instance_type
    instance_count = 2
    name           = "Core - 2"

    ebs_config {
      size                 = "32"
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }
}

# Set up Redshift
resource "aws_redshift_cluster" "yt_de_redshift_cluster" {
  cluster_identifier  = "yt-de-redshift-cluster"
  master_username     = var.redshift_user
  master_password     = var.redshift_password
  port                = 5439
  node_type           = var.redshift_node_type
  cluster_type        = "single-node"
  iam_roles           = [aws_iam_role.yt_de_redshift_iam_role.arn]
  skip_final_snapshot = true
}

# Create Redshift spectrum schema
provider "redshift" {
  host     = aws_redshift_cluster.yt_de_redshift_cluster.dns_name
  username = var.redshift_user
  password = var.redshift_password
  database = "dev"
}

# External schema using AWS Glue Data Catalog
resource "redshift_schema" "external_from_glue_data_catalog" {
  name  = "spectrum"
  owner = var.redshift_user
  external_schema {
    database_name = "spectrum"
    data_catalog_source {
      region                                 = var.aws_region
      iam_role_arns                          = [aws_iam_role.yt_de_redshift_iam_role.arn]
      create_external_database_if_not_exists = true
    }
  }
}

# Create EC2 with IAM role to allow EMR, Redshift, & S3 access and security group 
resource "tls_private_key" "custom_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name_prefix = var.key_name
  public_key      = tls_private_key.custom_key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240411"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "yt_de_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name             = aws_key_pair.generated_key.key_name
  security_groups      = [aws_security_group.yt_de_security_group.name]
  iam_instance_profile = aws_iam_instance_profile.yt_de_ec2_iam_role_instance_profile.id
  tags = {
    Name = "yt_de_ec2"
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "-------------------------START AIRFLOW SETUP---------------------------"
              # Update packages and install necessary tools
              sudo apt-get -y update
              sudo apt-get -y install ca-certificates curl gnupg lsb-release
              sudo apt -y install unzip
             

              # Install Docker
              # curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              # echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              
              sudo apt-get -y update
              sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
              sudo chmod 666 /var/run/docker.sock

              sudo apt install make
              # sudo systemctl enable docker
              # sudo systemctl start docker
              # sudo usermod -aG docker $USER

              # Clone git repo to EC2
              cd /home/ubuntu && git clone https://github.com/mustafaddogann/yt_de_project.git && cd yt_de_project && make perms

              echo 'Setup Airflow environment variables'
              echo "
              AIRFLOW_CONN_REDSHIFT=postgres://${var.redshift_user}:${var.redshift_password}@${aws_redshift_cluster.yt_de_redshift_cluster.endpoint}/dev
              AIRFLOW_CONN_POSTGRES_DEFAULT=postgres://airflow:airflow@localhost:5439/airflow
              AIRFLOW_CONN_AWS_DEFAULT=aws://?region_name=${var.aws_region}
              AIRFLOW_VAR_EMR_ID=${aws_emr_cluster.yt_de_emr_cluster.id}
              AIRFLOW_VAR_BUCKET=${aws_s3_bucket.yt-de-data-lake.id}
              " > env

              echo 'Start Airflow containers'
              # cd /home/ubuntu/yt_de_project && 
              make up
              echo "-------------------------END AIRFLOW SETUP---------------------------"
              EOF
}



resource "aws_budgets_budget" "cost" {
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}