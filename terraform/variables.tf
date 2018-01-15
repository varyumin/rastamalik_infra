variable zone {
  description = "Zone"
default = "europe-west1-d"
}

variable project {
  description = "Project ID"
default = "clever-overview-188908"
}

variable region {
  description = "Region"
  default     = "europe-west1"
}


variable app_disk_image {
  description = "Disk image for reddit app"
  default     = "reddit-app-base"
}

variable db_disk_image {
  description = "Disk image for reddit db"
  default     = "reddit-db-base"
}

