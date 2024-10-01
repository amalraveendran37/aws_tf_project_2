resource "aws_vpc" "myvpc" {
    cidr_block = var.cider
  
}

resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

  
}

resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id
  
}
resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0"
        gateway_id = aws_internet_gateway.igw.id
    }
  
}
resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub1.id 
    route_table_id = aws_route_table.rt.id
  
}
resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id 
    route_table_id = aws_route_table.rt.id
  
}
resource "aws_security_group" "project_security_group" {
  name   = "project_security_group"
  vpc_id = aws_vpc.myvpc.id
   ingress {
    description = "http"
    to_port     = 80
    from_port   = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "ssh"
    to_port     = 22
    from_port   = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    to_port     = 0
    from_port   = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
    
  }
}
resource "aws_s3_bucket" "my_bucket" {
    bucket = "project_bucket_1001"
}







resource "aws_instance" "webserver_1" {
    ami = "ami-02c21308fed24a8ab"
    instance_type = "t2.micro"
    vpc_security_group_ids =aws_security_group.project_security_group.id
    subnet_id = aws_subnet.sub1.id
    user_data = filebase64("./userdata.sh")
}

resource "aws_instance" "webserver_2" {
    ami = "ami-02c21308fed24a8ab"
    instance_type = "t2.micro"
    vpc_security_group_ids =[aws_security_group.project_security_group.id]
    subnet_id = aws_subnet.sub2.id
    user_data = filebase64("./userdata_1.sh")
}

# creating application load balacer
resource "aws_alb" "project_alb" {
    name = "project-alb"
    # public
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.project_security_group.id]
    subnets = [aws_subnet.sub1.id,aws_subnet.sub2.id]
    tags = {
      name="application_lb"
    }

}

resource "aws_alb_target_group" "target_group" {
    name="project-target-group"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.myvpc.id
    health_check {
      path = "/"
      port = "traffic-port"
    }
}
resource "aws_alb_target_group_attachment" "attachment_1" {
    target_group_arn = aws_alb_target_group.target_group.arn 
    target_id = aws_instance.webserver_1.id
    port = 80
}

resource "aws_alb_target_group_attachment" "attachment_2" {
    target_group_arn = aws_alb_target_group.target_group.arn 
    target_id = aws_instance.webserver_2.id
    port = 80
}
resource "aws_alb_listener" "listener" {
    load_balancer_arn = aws_alb.project_alb.arn
    port = 80
    protocol = "HTTP"
    default_action {
      target_group_arn = aws_alb_target_group.target_group.arn
      type = "forward"
    }
  
}
output "loadbalancerdns" {
    value = aws_alb.project_alb.dns_name
  
}