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
    Name = "public_subnet"  
  }
}

#private-subnet
resource "aws_subnet" "private-subnet" {
  vpc_id     = "${aws_vpc.myvpc1.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private_subnet"
  }
}

#Elastip IP for NAT Gateway
resource "aws_eip" "elasticip"{
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.elasticip.id
  subnet_id = aws_subnet.public-subnet.id
  
  tags = {
    Name = "Natgw"
  }
}


#internet gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = "${aws_vpc.myvpc1.id}"
  tags = {
    Name = "snehalgw"
  }  
}

#roting table1
resource "aws_route_table" "igwrt" {
  vpc_id = aws_vpc.myvpc1.id

   tags = {
    Name = "internet_gw_rt"
  }
}

resource "aws_route" "r1" {
  route_table_id = aws_route_table.igwrt.id
  destination_cidr_block ="0.0.0.0/0"
  gateway_id     = aws_internet_gateway.internet-gateway.id
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.igwrt.id
}




#roting table2
resource "aws_route_table" "ngwrt" {
  vpc_id = aws_vpc.myvpc1.id

   tags = {
    Name = "nat_gw_rt"
  }
}

resource "aws_route" "r2" {
  route_table_id = aws_route_table.ngwrt.id
  destination_cidr_block ="0.0.0.0/0"
  gateway_id     = aws_nat_gateway.nat.id
}


resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.ngwrt.id
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

#security group fro wordpress
resource "aws_security_group" "wp_sg" {
  name        = "wordpress"
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
resource "aws_instance" "wordpress" {
  ami           = "ami-004a955bfb611bf13"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public-subnet.id}"
  security_groups = ["${aws_security_group.wp_sg.id}"]
  key_name = "new_key"
  tags = {
    Name = "Wordpress_OS"
  }
  
}

//Security Group
resource "aws_security_group" "mysg" {
  name        = "sg_mysql"
  description = "Allow MYSQL"
  vpc_id      = aws_vpc.myvpc1.id
 
 ingress {
    description = "MYSQL/Aurora"
    from_port   = 0
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ aws_security_group.wp_sg.id ]
  }
   
   ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ aws_security_group.wp_sg.id ]
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
  security_groups=[aws_security_group.mysg.id]
  key_name = "new_key"
  tags = {
    Name = "MySQL_OS"
  }
}
