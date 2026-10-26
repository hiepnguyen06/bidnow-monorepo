variable "name" {
  description = "Name prefix applied to every resource."
  type        = string
}

variable "mail" {
  description = "SMTP settings. Port is a string because ECS secrets inject strings."
  type = object({
    host     = string
    port     = string
    username = string
    password = string
    from     = string
  })
  sensitive = true
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
