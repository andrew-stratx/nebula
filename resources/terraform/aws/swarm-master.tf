locals {
  master_user_data = <<TFEOF
#!/bin/sh

# Remove old instances of Docker which might ship with ubuntu
apt-get remove docker docker-engine docker.io

apt-get update
apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
# Complete fingerprint: 9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88
apt-key fingerprint 0EBFCD88

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

apt-get update
apt-get install -y docker-ce

export BOYAR_VERSION=e44569483b36914d2651ef65cede0730365d161c

curl -L https://s3.amazonaws.com/orbs-network-releases/infrastructure/boyar/boyar-$BOYAR_VERSION.bin -o /usr/bin/boyar && chmod +x /usr/bin/boyar

apt-get install -y python-pip && pip install awscli

docker swarm init

aws secretsmanager create-secret --region ${var.region} --name swarm-token-worker-${var.region} --secret-string $(docker swarm join-token --quiet worker) || aws secretsmanager put-secret-value --region ${var.region} --secret-id swarm-token-worker-${var.region} --secret-string $(docker swarm join-token --quiet worker)

mkdir -p /opt/orbs && mv /tmp/keys.json /opt/orbs

$(aws ecr get-login --no-include-email --region us-west-2)

while true; do
    [ $(docker node ls -q | wc -l) -eq 3 ] && HOME=/root boyar --config-url https://s3-us-west-2.amazonaws.com/orbs-network-config-staging/discovery/config.json --orchestrator swarm --keys /opt/orbs/keys.json && sleep 15 && break;
done
TFEOF
}

resource "aws_instance" "master" {
  ami                  = "${var.aws_ami_id}"
  instance_type        = "${var.aws_orbs_master_instance_type}"
  security_groups      = ["${aws_security_group.swarm.name}"]
  key_name             = "${aws_key_pair.deployer.key_name}"
  iam_instance_profile = "orbs-network"

  user_data = "${local.master_user_data}"

  tags = {
    Name = "constellation-swarm-master"
  }

  provisioner "file" {
    source      = "~/gopath/src/github.com/orbs-network/boyarin/e2e-config/node2/keys.json"
    destination = "/tmp/keys.json"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
}