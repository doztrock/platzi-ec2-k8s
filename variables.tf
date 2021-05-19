variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}

variable "AWS_SESSION_TOKEN" {
  type    = string
  default = null
}

variable "AWS_DEFAULT_REGION" {
  type = string
}

variable "EC2_INSTANCE_CONNECT" {
  type = bool
}

variable "PUBLIC_IP" {
  type    = string
  default = null
}

variable "SSH_PUBLIC_KEY" {
  type    = string
  default = null
}
