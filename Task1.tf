provider "aws" {
    profile = "Mahima"
    region  = "ap-south-1"
}

resource "aws_key_pair" "Task1_Key" {
  key_name = "Task1Key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAuBLN+LvEUNZxIVqXizPaJfMlCnJv5uXPHRH5VQz/UzuRhfBY/kOa6lSggxVcPDCq8XgcRMU51fl22cwoe4NZNRJthK3cCVpg+z9E/g378ubp4x/8jobdXEmx7xhoDJ17/adBo4pU6eBUW3EPKUxL7L9KOF49KyXGnSLBrQK52iTLz6dsafMDcbxMxXKyqcyqI2inRF2lxJkWr44QaJfuWGlzA+iwP7XFiBFqAt2gBpnp6L0sr4K8hhBHbP2kUsk7MWMo1d0J3lHiH99ZgPgum0RjGrrgGdGCyaS2lI+9KKHp22HGh+xFcMkyonTXdlYdRf5C8u+vXja92Ge0kA9OCw== rsa-key-20200612"
}

resource "aws_security_group" "Task1_SecGrp" {
  name        = "Task1SecGrp"
  
  ingress {
    description = "allow http traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow ssh login"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Task1SecGrp"
  }
}

output "O1"{
 value =aws_security_group.Task1_SecGrp.id 
}


resource "aws_instance" "Task1_WebOS" {
  depends_on = [
     aws_key_pair.Task1_Key,
     aws_security_group.Task1_SecGrp
  ]

  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.Task1_Key.key_name
  security_groups = [aws_security_group.Task1_SecGrp.name]

  tags = {
    Name = "Task1WebOS"
  }

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Home/Downloads/Task1Key.pem")
    host     = aws_instance.Task1_WebOS.public_ip
  }
 provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

}

output "O2"{
  value = aws_instance.Task1_WebOS.public_ip
}

resource "aws_ebs_volume" "Task1_EBS" {
 depends_on = [
   aws_instance.Task1_WebOS
 ]

  availability_zone = aws_instance.Task1_WebOS.availability_zone
  size              = 1
  tags = {
    Name = "Task1EBS"
  }
}

resource "aws_volume_attachment" "Task1EBS_att" {
  depends_on = [
     aws_ebs_volume.Task1_EBS
  ]
  device_name = "/dev/sdm"
  volume_id   = aws_ebs_volume.Task1_EBS.id
  instance_id = aws_instance.Task1_WebOS.id
  force_detach = true
}

resource "null_resource" "Task1EBS_Mount"  {

  depends_on = [
    aws_volume_attachment.Task1EBS_att
  ]
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Home/Downloads/Task1Key.pem")
    host     = aws_instance.Task1_WebOS.public_ip
  }
 provisioner "remote-exec" {
    inline = [
        "sudo mkfs.ext4  /dev/xvdm",
      "sudo mount  /dev/xvdm  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Mahima-Pal/Task1.git /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "Task1_bucket" {
  bucket = "task1bucket111"
  acl    = "public-read"

  tags = {
    Name        = "Task1Bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_object" "Task1_Object" {
  bucket = aws_s3_bucket.Task1_bucket.bucket
  key    = "Task1_image"
  source = "E:/wallpapers/Task1_image.png"
  acl = "public-read"
  content_type = "image/png"
}


variable "var1" {default = "S3-"}
locals {
    s3_origin_id = "${var.var1}${aws_s3_bucket.Task1_bucket.bucket}"
    image_url = "${aws_cloudfront_distribution.Task1_s3_distribution.domain_name}/${aws_s3_bucket_object.Task1_Object.key}"
}
resource "aws_cloudfront_distribution" "Task1_s3_distribution" {
    default_cache_behavior {
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
       min_ttl = 0
       default_ttl = 3600
       max_ttl = 86400
      compress = true
        viewer_protocol_policy = "allow-all"
    }
enabled             = true
origin {
        domain_name = aws_s3_bucket.Task1_bucket.bucket_domain_name
        origin_id   = local.s3_origin_id
    }
restrictions {
        geo_restriction {
        restriction_type = "whitelist"
        locations = ["IN"]
        }
    }
viewer_certificate {
        cloudfront_default_certificate = true
    }

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Home/Downloads/Task1Key.pem")
    host     = aws_instance.Task1_WebOS.public_ip	
}


provisioner "remote-exec" {
	inline = [
	"sudo su << EOF",
	"echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.Task1_Object.key}' width='300' height='400'>\" >> /var/www/html/index.php",
	"EOF",
	]
}

provisioner "local-exec" {
		command = "start chrome ${aws_instance.Task1_WebOS.public_ip}"
	}
}      

















