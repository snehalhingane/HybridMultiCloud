#aws provider
provider "aws" {
region = "ap-south-1"
profile = "snehal"
}

#EFS
resource "aws_efs_file_system" "myefs" {
depends_on = [
  aws_subnet.public-subnet,
]
  creation_token = "myefs"
  performance_mode = "generalPurpose"
}

#creating VPC
resource "aws_vpc" "myvpc13" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "myvpc"
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id     = "${aws_vpc.myvpc13.id}"
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "snehalsub1"  
  }
}

resource "aws_efs_mount_target" "efs_mount" {
  depends_on=[aws_efs_file_system.myefs, ]
  file_system_id = "${aws_efs_file_system.myefs.id}"
  subnet_id      = "${aws_subnet.public-subnet.id}"
  security_groups=[aws_security_group.new_sg1.id]
}

resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = "${aws_vpc.myvpc13.id}"
  tags = {
    Name = "snehalgw"
  }  
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.myvpc13.id

   tags = {
    Name = "route_table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.r.id
}

resource "aws_route" "b" {
  route_table_id = aws_route_table.r.id
  destination_cidr_block ="0.0.0.0/0"
  gateway_id     = aws_internet_gateway.internet-gateway.id
}


#create key pair
resource "tls_private_key" "key1" {
	algorithm = "RSA"
	rsa_bits =4096
}
resource "local_file" "mytaskkey_access" {
content = tls_private_key.key1.private_key_pem
filename = "key1.pem"
}
resource "aws_key_pair" "generated_key" {
key_name = "key1"
public_key = tls_private_key.key1.public_key_openssh
}

variable "mykey1" {
default = "key1"
}

#create security group
//Security Group

resource "aws_security_group" "new_sg1" {
  name        = "sg_my"
  description = "Allow MYSQL"
  vpc_id      = aws_vpc.myvpc13.id

   
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.public-subnet.cidr_block}"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["${aws_subnet.public-subnet.cidr_block}"]
  }
  ingress {
    description = "ICMP - IPv4"
    from_port = -1
    to_port	= -1
    protocol	= "icmp"
    cidr_blocks = ["${aws_subnet.public-subnet.cidr_block}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "mysecurity"
  } 
}


resource "aws_instance" "m1" {
  ami           = "ami-005956c5f0f757d37"
  instance_type = "t2.micro"
  key_name      = "key1.pem"
  subnet_id    = "${aws_subnet.public-subnet.id}"
  vpc_security_group_ids = [ "${aws_security_group.new_sg1.id}" ]
  user_data = <<-EOF
                #! /bin/bash
                #cloud-config
                repo_update: true
                repo_upgrade: all
                sudo yum install httpd -y
                sudo systemctl start httpd
                sudo systemctl enable httpd
                yum install -y amazon-efs-utils
apt-get -y install amazon-efs-utils
yum install -y nfs-utils
apt-get -y install nfs-common
file_system_id_1="${aws_efs_file_system.myefs.id}"
efs_mount_point_1="/var/www/html"
mkdir -p "$efs_mount_point_1"
test -f "/sbin/mount.efs" && echo "$file_system_id_1:/ $efs_mount_point_1 efs tls,_netdev" >> /etc/fstab || echo "$file_system_id_1.efs.ap-south-1.amazonaws.com:/ $efs_mount_point_1 nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0" >> /etc/fstab
test -f "/sbin/mount.efs" && echo -e "\n[client-info]\nsource=liw" >> /etc/amazon/efs/efs-utils.conf
mount -a -t efs,nfs4 defaults


  EOF

  tags = {
    Name = "task2os"
  }
}

#mounting
resource "null_resource" "nullremote1" {
depends_on = [
	aws_efs_file_system.myefs,
	]

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.key1.private_key_pem
    host     = aws_instance.m1.public_ip
  }

provisioner "remote-exec" {
	inline = [
	"sudo yum install -y amazon-efs-utils",
      "efs_id=aws_efs_file_system.myefs",
      "sudo mount -t efs $efs_id:/ /var/www/html",
      "sudo mkfs.ext4  /dev/xvdh",
      "echo $efs_id:/ /efs efs defaults,_netdev 0 0 >> /etc/fstab",
	]
           }
      }
#creating bucket
resource "aws_s3_bucket" "ps" {
  bucket = "bucket112211"
  acl    = "public-read"
 
}

resource "aws_s3_bucket_object" "object1" {
depends_on = [aws_s3_bucket.ps, ]
   bucket ="bucket1122"
   key    = "macQueen.jpeg"
   source = "C:/Users/Administrator/Downloads/macQueen.jpeg" 
   acl = "public-read" 
}
locals {
	s3_origin_id = "S3-bucket112211"
}

resource "aws_cloudfront_origin_access_identity" "cf" {
comment= "This is OAI"
}

#cloudfront
resource "aws_cloudfront_distribution" "s3_distribution" {
	depends_on = [
aws_cloudfront_origin_access_identity.cf,null_resource.nullremote1,
]

origin {
domain_name = aws_s3_bucket.ps.bucket_domain_name
origin_id = local.s3_origin_id

s3_origin_config {
	origin_access_identity = aws_cloudfront_origin_access_identity.cf.cloudfront_access_identity_path
}
}

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.key1.private_key_pem
    host     = aws_instance.m1.public_ip
  }

provisioner "remote-exec" {
	inline = [
	"sudo su << EOF",
	"echo \"<img src='http://${self.domain_name}${aws_s3_bucket_object.object1.key}'>\" >> /var/www/html/index.html",
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
	value = aws_instance.m1.public_ip
	}


