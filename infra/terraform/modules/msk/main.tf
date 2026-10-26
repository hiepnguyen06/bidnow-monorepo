locals {
  tags = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-msk"
  description = "Kafka TLS access for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-msk" })
}

# Standalone rules only: one rule per allowed security group. No egress is needed.
resource "aws_vpc_security_group_ingress_rule" "from_allowed" {
  count = length(var.allowed_sg_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "Kafka TLS from allowed security group"
  ip_protocol                  = "tcp"
  from_port                    = 9094
  to_port                      = 9094
  referenced_security_group_id = var.allowed_sg_ids[count.index]
}

locals {
  # MSK deprecates old versions and then refuses to create clusters on them (3.6.0 is
  # DEPRECATED and was rejected). List what is currently allowed with:
  #   aws kafka list-kafka-versions --region ap-southeast-2
  # 3.9.x is the ZooKeeper-mode line; "3.9.x.kraft" is the KRaft equivalent.
  kafka_version = "3.9.x"
}

# The MSK default disables topic auto-creation; the services rely on it.
resource "aws_msk_configuration" "this" {
  name           = "${var.name}-msk"
  kafka_versions = [local.kafka_version]

  server_properties = <<-EOT
    auto.create.topics.enable=true
    default.replication.factor=2
    min.insync.replicas=1
    num.partitions=3
    offsets.topic.replication.factor=2
    transaction.state.log.replication.factor=2
    transaction.state.log.min.isr=1
  EOT
}

resource "aws_msk_cluster" "this" {
  cluster_name           = "${var.name}-msk"
  kafka_version          = local.kafka_version
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.this.id]

    storage_info {
      ebs_storage_info {
        volume_size = 10
      }
    }
  }

  # TLS only. With no client_authentication block, clients are unauthenticated
  # and access is restricted by the security group.
  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  tags = merge(local.tags, { Name = "${var.name}-msk" })
}
