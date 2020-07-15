provider "aws" {
    region ="ap-south-1"
    profile = "snehal"
  
}

resource "aws_vpc" "myvpc1" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "myvpc"
  }
}

#public-subnet
resource "aws_subnet" "public-subnet" {
  vpc_id     = "${aws_vpc.myvpc1.id}"
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "snehalsub1"  
  }
}

#private-subnet
resource "aws_subnet" "private-subnet" {
  vpc_id     = "${aws_vpc.myvpc1.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "snehalsub2"
  }
}

#internet gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = "${aws_vpc.myvpc1.id}"
  tags = {
    Name = "snehalgw"
  }  
}

#roting table
resource "aws_route_table" "r" {
  vpc_id = aws_vpc.myvpc1.id

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

//Creating key
resource "tls_private_key" "mykey"{
 algorithm = "RSA"
}
module "key_pair"{
 source ="terraform-aws-modules/key-pair/aws"

 key_name = "new_key"
 public_key = tls_private_key.mykey.public_key_openssh
}

#security group
resource "aws_security_group" "new_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc1.id

  ingress {
    description = "ssh"
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http"
    from_port   = 0
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
    Name ="sgforWordPress"
  }
}

//Launching Instance
resource "aws_instance" "myweb" {
  ami           = "ami-004a955bfb611bf13"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.new_sg.id}"]
  key_name = "new_key"
  tags = {
    Name = "Webserver"
  }
  
}

//Security Group
resource "aws_security_group" "new_sg2" {
  name        = "sg_mysql"
  description = "Allow MYSQL"
  vpc_id      = aws_vpc.myvpc1.id 
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
    Name = "mysqlSG"
  } 
}

//Launching Instance
resource "aws_instance" "mysql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.new_sg2.id}"]
  key_name = "new_key"
  tags = {
    Name = "MySQL"
  }
}
