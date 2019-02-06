resource "aws_ebs_volume" "ethereum" {
  count             = "${var.ethereum_count}"
  availability_zone = "${var.aws_ether_az}"
  size              = 100
}

resource "aws_volume_attachment" "ethereum_storage_attachment" {
  count       = "${var.ethereum_count}"
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ethereum.id}"
  instance_id = "${aws_instance.ethereum.id}"
}
