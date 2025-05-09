variable "region" {
  type        = string
  default     = "ap-south-2"
  description = "The AWS Region to deploy OpenOps"
}

variable "volume_size" {
  type    = number
  default = 20
}

variable "volume_type" {
  type    = string
  default = "gp3"
}

variable "instance_config" {
  description = "Map of diff instance configurations"
  type = map(object({
    ami           = string
    instance_type = string
  }))
  default = {
    "ubuntu_instance_24_04" = {
      ami           = "ami-053a0835435bf4f45"
      instance_type = "t3.medium"

    }
    "ubuntu_instance_22_04" = {
      ami           = "ami-0995f69ccfab3ef18"
      instance_type = "t3.medium"

    }
  }
}

variable "email_address" {
  type    = string
  default = "lyadellanaveen@gmail.com"
}
