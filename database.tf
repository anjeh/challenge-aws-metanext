resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "main" {
  identifier                  = "${var.project_name}-postgres"
  engine                      = "postgres"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true # AWS creates a Secrets Manager secret.
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  publicly_accessible         = false
  multi_az                    = var.db_multi_az # true = standby in another AZ (higher RDS cost).
  backup_retention_period     = 7
  deletion_protection         = false # Challenge teardown; change to true for production.
  skip_final_snapshot         = true  # Challenge teardown; not production-safe.
}
