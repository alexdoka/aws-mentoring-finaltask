### PREREQUISITES
1. You have to set up AWS access by:
```bash
aws configure
```
2. Set in AWS Parameter store password to AWS RDS (path /finaltask/db-password) 
3. And before deploying you have to have locally docker image **ghost:latest**
4. Go to folder stack_app and run 
```bash
terraform init
terraform apply
```
