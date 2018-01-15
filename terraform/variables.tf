variable zone {
  description = "Zone"
}

variable project {
  description = "Project ID"
}

variable region {
  description = "Region"
  default     = "europe-west1"
}

variable public_key_path {
  description = "Path to the public key used for ssh access"
}

variable disk_image {
  description = "Disk image"
}

variable private_key {
  description = "private ssh key"
}

variable ssh_users {
<<<<<<< HEAD
description = "SSH User"
}

variable ssh_rsa {
description = "Ssh-rsa"
}
variable count {
description = "count"
}
=======
  description = "SSH User"
}

variable ssh_rsa {
  description = "Ssh-rsa"
}

variable count {
  description = "count"
}

variable app_disk_image {
  description = "Disk image for reddit app"
  default     = "reddit-base"
}

variable db_disk_image {
  description = "Disk image for reddit db"
  default     = "reddit-base"
}

>>>>>>> terraform2
