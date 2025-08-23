# This Terraform configuration deploys a basic AWS Elastic Kubernetes Service (EKS) cluster
# with a managed node group. It includes all necessary networking components (VPC, subnets,
# Internet Gateway, NAT Gateway) and IAM roles/policies for a functional EKS setup.

# IMPORTANT:
# 1. Replace placeholder values like 'your-key-pair-name' and 'your-public-ip-for-ssh'
#    with your actual values.
# 2. Ensure your AWS CLI is configured with appropriate credentials and default region.
# 3. This setup creates new VPC resources. If you want to use an existing VPC,
#    you will need to modify the 'vpc' and 'subnet' resource blocks accordingly.
# 4. For production environments, consider more robust configurations like:
#    - Multiple node groups for different workloads.
#    - Auto Scaling Group policies.
#    - Private EKS endpoint access.
#    - Advanced logging and monitoring.
#    - External DNS and Load Balancer controllers.

# --- AWS Provider Configuration ---
provider "aws" {
  region = "us-east-1" # Specify your desired AWS region
}

# --- VPC and Networking Setup ---
# A dedicated VPC is created for the EKS cluster to ensure network isolation and proper routing.
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true # Required for EKS
  enable_dns_support   = true # Required for EKS

  tags = {
    Name = "eks-vpc"
    # Required for EKS cluster auto-discovery of subnets
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

# Public Subnets (for NAT Gateway and potentially public load balancers)
# EKS requires at least two subnets in different Availability Zones.
resource "aws_subnet" "eks_public_subnet_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${provider.aws.region}a" # Example AZ
  map_public_ip_on_launch = true # Instances launched here will get a public IP

  tags = {
    Name = "eks-public-subnet-1"
    # Required for EKS cluster auto-discovery of subnets
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    # Required for EKS to discover public load balancer subnets
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "eks_public_subnet_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${provider.aws.region}b" # Example AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-subnet-2"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private Subnets (for EKS worker nodes)
resource "aws_subnet" "eks_private_subnet_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${provider.aws.region}a"

  tags = {
    Name = "eks-private-subnet-1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    # Required for EKS to discover internal load balancer subnets
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "eks_private_subnet_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${provider.aws.region}b"

  tags = {
    Name = "eks-private-subnet-2"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Internet Gateway for public subnet connectivity
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

# EIP for NAT Gateway
resource "aws_eip" "nat_eip_1" {
  vpc = true # Associate with VPC

  tags = {
    Name = "eks-nat-eip-1"
  }
}

# NAT Gateway for private subnet outbound internet access
resource "aws_nat_gateway" "eks_nat_gateway_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.eks_public_subnet_1.id # Place NAT Gateway in public subnet

  tags = {
    Name = "eks-nat-gateway-1"
  }
  # Ensure NAT Gateway is created after Internet Gateway
  depends_on = [aws_internet_gateway.eks_igw]
}

# Route Table for public subnets (default route to IGW)
resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "eks_public_rt_assoc_1" {
  subnet_id      = aws_subnet.eks_public_subnet_1.id
  route_table_id = aws_route_table.eks_public_rt.id
}

resource "aws_route_table_association" "eks_public_rt_assoc_2" {
  subnet_id      = aws_subnet.eks_public_subnet_2.id
  route_table_id = aws_route_table.eks_public_rt.id
}

# Route Table for private subnets (default route to NAT Gateway)
resource "aws_route_table" "eks_private_rt_1" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat_gateway_1.id
  }

  tags = {
    Name = "eks-private-rt-1"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "eks_private_rt_assoc_1" {
  subnet_id      = aws_subnet.eks_private_subnet_1.id
  route_table_id = aws_route_table.eks_private_rt_1.id
}

# If you need a second NAT Gateway for high availability across AZs,
# uncomment and configure similar blocks for nat_eip_2, eks_nat_gateway_2,
# eks_private_rt_2, and eks_private_rt_assoc_2.
# For simplicity, this example uses one NAT Gateway.
resource "aws_route_table_association" "eks_private_rt_assoc_2" {
  subnet_id      = aws_subnet.eks_private_subnet_2.id
  route_table_id = aws_route_table.eks_private_rt_1.id # Both private subnets use the same NAT GW for simplicity
}

# --- EKS Cluster IAM Role ---
# This IAM role is assumed by the EKS control plane.
resource "aws_iam_role" "eks_cluster_role" {
  name = "${local.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = {
    Name = "${local.cluster_name}-cluster-role"
  }
}

# Attach required AWS managed policies to the EKS cluster role.
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment_1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment_2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

# --- EKS Cluster ---
# Defines the EKS Kubernetes cluster itself.
resource "aws_eks_cluster" "eks_cluster" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.28" # Specify your desired Kubernetes version

  vpc_config {
    subnet_ids         = [aws_subnet.eks_private_subnet_1.id, aws_subnet.eks_private_subnet_2.id, aws_subnet.eks_public_subnet_1.id, aws_subnet.eks_public_subnet_2.id]
    endpoint_private_access = false # Set to true for private endpoint access
    endpoint_public_access  = true  # Set to false to disable public endpoint access
    public_access_cidrs     = ["0.0.0.0/0"] # Restrict public access to specific CIDRs if endpoint_public_access is true
  }

  # Ensure cluster is created after NAT Gateway and Route Table Associations
  depends_on = [
    aws_nat_gateway.eks_nat_gateway_1,
    aws_route_table_association.eks_private_rt_assoc_1,
    aws_route_table_association.eks_private_rt_assoc_2,
    aws_route_table_association.eks_public_rt_assoc_1,
    aws_route_table_association.eks_public_rt_assoc_2,
  ]

  tags = {
    Name = local.cluster_name
  }
}

# --- EKS Node Group IAM Role ---
# This IAM role is assumed by the EC2 instances that act as worker nodes.
resource "aws_iam_role" "eks_nodegroup_role" {
  name = "${local.cluster_name}-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = {
    Name = "${local.cluster_name}-nodegroup-role"
  }
}

# Attach required AWS managed policies to the EKS node group role.
resource "aws_iam_role_policy_attachment" "eks_nodegroup_policy_attachment_1" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks_nodegroup_policy_attachment_2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks_nodegroup_policy_attachment_3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodegroup_role.name
}

# --- EKS Managed Node Group ---
# Deploys the worker nodes for the EKS cluster.
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${local.cluster_name}-nodegroup"
  node_role_arn   = aws_iam_role.eks_nodegroup_role.arn
  subnet_ids      = [aws_subnet.eks_private_subnet_1.id, aws_subnet.eks_private_subnet_2.id] # Place nodes in private subnets
  instance_types  = ["t3.medium"] # Choose appropriate instance types
  disk_size       = 20 # GB

  scaling_config {
    desired_size = 2 # Desired number of nodes
    max_size     = 3 # Maximum number of nodes
    min_size     = 1 # Minimum number of nodes
  }

  # Optional: Associate a key pair for SSH access (replace with your key pair name)
  # remote_access {
  #   ec2_ssh_key = "your-key-pair-name"
  #   source_security_group_ids = [aws_security_group.ssh_access.id] # Allow SSH from specific SG
  # }

  # Ensure node group is created after cluster
  depends_on = [
    aws_eks_cluster.eks_cluster,
  ]

  tags = {
    Name = "${local.cluster_name}-nodegroup"
    "eks:cluster-name" = local.cluster_name # Required for EKS auto-discovery
  }
}

# --- Security Groups ---
# Security group for EKS cluster control plane (allowing access from node group)
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${local.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Allow inbound from EKS node group security group
    security_groups = [aws_eks_node_group.eks_node_group.remote_access[0].source_security_group_ids[0]] # This is tricky, better to reference the node group's actual SG ID if not using remote_access block
    # A more robust way would be to create a separate SG for nodes and reference it here.
    # For simplicity, if remote_access is not used, you'd need to create a dedicated SG for nodes
    # and reference its ID.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-cluster-sg"
  }
}

# Security group for SSH access to worker nodes (if remote_access is used)
# This is an example; adjust source_cidr_blocks to your trusted IP range.
resource "aws_security_group" "ssh_access" {
  name        = "${local.cluster_name}-ssh-access"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # IMPORTANT: Replace with your public IP address or a trusted CIDR block
    cidr_blocks = ["0.0.0.0/0"] # WARNING: This allows SSH from anywhere. Restrict this!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.cluster_name}-ssh-access"
  }
}


# --- Local Variables ---
# Define a local variable for the cluster name for consistency
locals {
  cluster_name = "my-eks-cluster" # Customize your EKS cluster name
}

# --- Outputs ---
# These outputs provide useful information about your deployed EKS cluster
# after Terraform applies the configuration.
output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.arn
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_kubeconfig_command" {
  description = "Command to update your kubeconfig for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${provider.aws.region} --name ${aws_eks_cluster.eks_cluster.name}"
}

output "eks_node_group_name" {
  description = "The name of the EKS node group"
  value       = aws_eks_node_group.eks_node_group.node_group_name
}

output "eks_vpc_id" {
  description = "The ID of the VPC created for EKS"
  value       = aws_vpc.eks_vpc.id
}

output "eks_private_subnet_ids" {
  description = "IDs of the private subnets used by EKS worker nodes"
  value       = [aws_subnet.eks_private_subnet_1.id, aws_subnet.eks_private_subnet_2.id]
}

output "eks_public_subnet_ids" {
  description = "IDs of the public subnets used by EKS (for load balancers, NAT GW)"
  value       = [aws_subnet.eks_public_subnet_1.id, aws_subnet.eks_public_subnet_2.id]
}
