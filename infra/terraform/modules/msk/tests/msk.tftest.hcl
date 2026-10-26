mock_provider "aws" {
  override_resource {
    target = aws_msk_configuration.this
    values = {
      arn             = "arn:aws:kafka:ap-southeast-2:123456789012:configuration/x/1"
      latest_revision = 1
    }
  }
}

variables {
  name           = "bidnow-test"
  vpc_id         = "vpc-123"
  subnet_ids     = ["subnet-a", "subnet-b"]
  allowed_sg_ids = ["sg-app1"]
}

run "msk_two_brokers_tls_only" {
  command = apply

  override_resource {
    target = aws_security_group.this
    values = { id = "sg-msk" }
  }

  assert {
    condition = (
      aws_msk_cluster.this.number_of_broker_nodes == 2 &&
      aws_msk_cluster.this.broker_node_group_info[0].instance_type == "kafka.t3.small" &&
      aws_msk_cluster.this.broker_node_group_info[0].storage_info[0].ebs_storage_info[0].volume_size == 10 &&
      toset(aws_msk_cluster.this.broker_node_group_info[0].client_subnets) == toset(["subnet-a", "subnet-b"]) &&
      tolist(aws_msk_cluster.this.broker_node_group_info[0].security_groups) == tolist(["sg-msk"])
    )
    error_message = "Expected 2 kafka.t3.small brokers with 10 GB each across both data subnets."
  }

  assert {
    condition = (
      aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].client_broker == "TLS" &&
      aws_msk_cluster.this.encryption_info[0].encryption_in_transit[0].in_cluster == true
    )
    error_message = "Encryption in transit must be TLS for clients and in-cluster."
  }

  assert {
    condition     = length(aws_msk_cluster.this.client_authentication) == 0
    error_message = "No client authentication block expected."
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.from_allowed) == 1 &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.from_allowed : r.referenced_security_group_id == "sg-app1" && r.from_port == 9094 && r.to_port == 9094 && r.ip_protocol == "tcp" && r.security_group_id == "sg-msk"])
    )
    error_message = "Ingress must be tcp/9094 from the allowed security group only."
  }
}

run "msk_config_enables_topic_autocreate" {
  command = plan

  assert {
    condition     = strcontains(aws_msk_configuration.this.server_properties, "auto.create.topics.enable=true")
    error_message = "Topic auto-creation must be enabled."
  }

  assert {
    condition     = strcontains(aws_msk_configuration.this.server_properties, "num.partitions=3")
    error_message = "Default partitions must be 3."
  }
}

run "msk_replication_factor_two" {
  command = plan

  assert {
    condition = (
      strcontains(aws_msk_configuration.this.server_properties, "default.replication.factor=2") &&
      strcontains(aws_msk_configuration.this.server_properties, "min.insync.replicas=1")
    )
    error_message = "Replication factor must be 2 with min.insync.replicas=1."
  }
}

run "msk_internal_topics_fit_two_brokers" {
  command = plan

  assert {
    condition     = strcontains(aws_msk_configuration.this.server_properties, "offsets.topic.replication.factor=2")
    error_message = "Consumer offsets topic must use replication factor 2."
  }

  assert {
    condition     = strcontains(aws_msk_configuration.this.server_properties, "transaction.state.log.replication.factor=2")
    error_message = "Transaction state log must use replication factor 2."
  }

  assert {
    condition     = strcontains(aws_msk_configuration.this.server_properties, "transaction.state.log.min.isr=1")
    error_message = "Transaction state log min ISR must be 1."
  }
}

run "msk_cluster_uses_configuration" {
  command = apply

  assert {
    condition     = aws_msk_cluster.this.configuration_info[0].arn == "arn:aws:kafka:ap-southeast-2:123456789012:configuration/x/1" && aws_msk_cluster.this.configuration_info[0].revision == 1
    error_message = "Cluster must use the custom configuration."
  }
}
