# Terraform code for an EC2 instance with access to an S3 bucket

## Prerquisites

- Environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_REGION` is set
- Terraform variables `ssh_ingress_cidr` for SSH IP whitelist, `key_pair_name` for SSH key pair and `resource_prefix` for resource prefix name

## Apply terraform

```
terraform init
terraform apply
```

## Install kURL into the VM

E.g.

```bash
[ec2-user@ip-172-31-16-78 ~]$ aws s3 ls s3://gerard-kots/
2024-08-13 00:39:47         13 thisistheway.txt
[ec2-user@ip-172-31-16-78 ~]$ curl https://kurl.sh/4bccc6e | sudo bash -s exclude-builtin-host-preflights
```
