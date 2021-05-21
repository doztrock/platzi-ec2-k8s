data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
    ]
  }
  filter {
    name = "root-device-type"
    values = [
      "ebs"
    ]
  }
  filter {
    name = "virtualization-type"
    values = [
      "hvm"
    ]
  }
  owners = [
    "099720109477"
  ]
}

resource "tls_private_key" "rsa" {
  count     = var.SSH_PUBLIC_KEY == null ? 1 : 0
  algorithm = "RSA"
}

module "sg-kubernetes" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name   = "kubernetes-sg"
  vpc_id = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp"]

  ingress_with_cidr_blocks = concat(
    [
      {
        rule        = "all-all"
        cidr_blocks = data.aws_vpc.default.cidr_block
        description = "ALL"
      }
    ],
    var.EC2_INSTANCE_CONNECT == true ? [
      {
        rule        = "ssh-tcp"
        cidr_blocks = lookup(local.EC2_INSTANCE_CONNECT, var.AWS_DEFAULT_REGION)
        description = "EC2_INSTANCE_CONNECT"
      }
    ] : [],
    var.PUBLIC_IP != null ? [
      {
        rule        = "ssh-tcp"
        cidr_blocks = var.PUBLIC_IP
        description = "SSH"
      }
    ] : [],
    var.EC2_INSTANCE_CONNECT != true && var.PUBLIC_IP == null ? [
      {
        rule        = "ssh-tcp"
        cidr_blocks = "0.0.0.0/0"
        description = "SSH"
      }
      ] : [
      {
        rule        = "ssh-tcp"
        cidr_blocks = data.aws_vpc.default.cidr_block
        description = "SSH"
      }
    ]
  )

  egress_rules = ["all-all"]

  tags = local.PROJECT_TAGS
}

module "key-kubernetes" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "1.0.0"

  key_name   = "kubernetes-key"
  public_key = var.SSH_PUBLIC_KEY == null ? tls_private_key.rsa[0].public_key_openssh : var.SSH_PUBLIC_KEY

  tags = local.PROJECT_TAGS
}

module "ec2-kubernetes-master" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.19.0"

  name = "kubernetes-master-ec2"

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"

  key_name = module.key-kubernetes.key_pair_key_name

  subnet_id                   = tolist(data.aws_subnet_ids.all.ids)[1]
  associate_public_ip_address = true

  vpc_security_group_ids = [module.sg-kubernetes.security_group_id]

  user_data = file("${path.module}/init.sh")

  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 30
    }
  ]

  tags        = local.PROJECT_TAGS
  volume_tags = local.PROJECT_TAGS
}

module "ec2-kubernetes-slave" {
  count   = 3
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.19.0"

  name = "kubernetes-slave-ec2"

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.small"

  key_name = module.key-kubernetes.key_pair_key_name

  subnet_id                   = tolist(data.aws_subnet_ids.all.ids)[0]
  associate_public_ip_address = true

  vpc_security_group_ids = [module.sg-kubernetes.security_group_id]

  user_data = file("${path.module}/init.sh")

  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 30
    }
  ]

  tags        = local.PROJECT_TAGS
  volume_tags = local.PROJECT_TAGS
}

resource "aws_eip" "eip-kubernetes-master" {
  vpc      = true
  instance = module.ec2-kubernetes-master.id[0]
  tags     = local.PROJECT_TAGS
}
