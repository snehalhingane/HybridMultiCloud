#creating profile
provider "aws" {
 region = "ap-south-1"
 profile = "snehal"
}

#key pair
resource "tls_private_key" "weboskey12" {
	algorithm = "RSA"
	rsa_bits =4096
}
resource "local_file" "mytaskkey_access" {
content = tls_private_key.weboskey12.private_key_pem
filename = "weboskey12.pem"
}
resource "aws key_pair" "generated_key" {
key_name = "weboskey12"
public_key = tls_private_key.weboskey12.public_key_openshh
}

variable "mykey1" {
default = "weboskey12"
}

resource "aws_security_group" "allow_ssh_and_http1" {
  name        = "allow_ssh_and_http_1"
  description = "Allow ssh and http inbound traffic"
  
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_and_http1"
  }
} 

resource "aws_instance" "mi" {
  ami = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name="weboskey12"
  security_groups = [ "allow_ssh_and_http" ]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.weboskey12.private_key_pem
    host     = aws_instance.mi.public_ip
  }

provisioner "remote-exec" {
      inline = [
	"sudo yum install httpd php git -y",
	"sudo systemctl restart httpd",
	"sudo systemctl enable httpd",
	]
}

  tags = {
    Name = "HelloWorld1"
  }
}

#creating EBS volume

resource "aws_ebs_volume" "ex" {
  availability_zone = aws_instance.mi.availability_zone
  size =1
  tags = {
    Name = "ebsvolume"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvdh"
  volume_id   = "${aws_ebs_volume.ex.id}"
  instance_id = "${aws_instance.mi.id}"
  force_detach = true
}

#mounting
resource "null_resource" "nullremote1" {
depends_on = [
	aws_volume_attachment.ebs_att,
	]

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_keyweboskey12.private_key_pem
    host     = aws_instance.mi.public_ip
  }

provisioner "remote-exec" {
	inline = [
	"sudo mkfs.ext4 /dev/xvdh",
	"sudo mount /dev/xvdh /var/www/html/",
	"sudo -rf /var/www/html/*",
	"sudo git clone https://github.com/snehalhingane/HybridMultiCloud.git  /var/www/html/"
	]
           }
      }

resource "aws_s3_bucket" "ps" {
  bucket = "nwbucket11223344"
  acl    = "public-read"
  
  tag = {
	 Name = "My bucket12"
 	 Environment = "Dev1"
	}
}

resource "aws_s3_bucket_object" "object1" {
depends_on = [aws_s3_bucket.ps, ]
   bucket =aws_s3_bucket.mybucket.bucket
   key    = "Photo.jpg"
   source = "C:/Users/Administrator/Downloads/Photo.jpg" 
   acl = "public-read" 
}
locals {
	s3_origin_id = "S3-nwbucket11223344"
}

resource "aws_cloudfront_origin_access_identity" "cfo" {
comment= "this is oai"
}

#cloudfront
resource "aws_cloudfront_distribution" "s3_distribution" {
	depends_on = [
aws_cloudfront_origin_access_identity.cfo,null_resource.nullremote1,
]

origin {
domain_name = aws_s3_bucket.ps.bucket_domain_name
origin_id = local.s3.origin_id

s3_origin_config {
	origin_access_identity = aws_cloudfront_origin_access_identity.cof.cloudfront_access_identity_path
}
}

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_keyweboskey12.private_key_pem
    host     = aws_instance.mi.public_ip
  }

provisioner "remote-exec" {
	inline = [
	"sudo su << EOF"
	"echo \"<img src='http://${self.domain_name}${aws_s3_bucket_object.object1.key}'>\" ?? /var/www/html/index.html",
	"EOF"
	]
           }
   
  enabled             = true
  is_ipv6_enabled     = true

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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

#ip
output "ip_of_inst" {
	value = aws_instance.mi.public_ip
	}


