# Rearc Quest on EKS (Managed Node Groups)




## Prereqs
- aws cli configured
- terraform
- docker
- helm (optional; terraform installs the chart)

## Repository Structure
```
.
├── app
│   ├── bin
│   └── src
├── certs
└── infra
```

---

## 1) Build & push image to ECR
1. Create ECR repo: rearc-quest
- aws ecr create-repository --repository-name rearc-quest
- aws ecr get-login-password | docker login --username AWS --password-stdin 971677725738.dkr.ecr.us-east-2.amazonaws.com

2. docker build + push:
   - docker build -t rearc-quest:latest ./app
   - docker tag rearc-quest:latest 971677725738.dkr.ecr.us-east-2.amazonaws.com/rearc-quest:latest
   - docker push 971677725738.dkr.ecr.us-east-2.amazonaws.com/rearc-quest:latest

## 2) Generate self-signed cert
- mkdir cert
From repo root:
- openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
  -keyout certs/key.pem \
  -out certs/cert.pem \
  -subj "/CN=rearc-quest.local"

## 3) Terraform apply (Phase 1)
cd infra
cp terraform.tfvars
terraform init
terraform apply

After apply:
- terraform output -raw configure_kubectl
- run that command to set kubeconfig

- aws eks update-kubeconfig --region us-east-2 --name rearc-quest-eks
- kubectl get nodes

Wait for ALB hostname:
- terraform output -raw alb_hostname
If empty at first, wait ~1-5 minutes and re-run.

Test index:
- curl -k https://<alb_hostname>/

Copy the SECRET_WORD from the response.

## 4) Terraform apply (Phase 2: inject SECRET_WORD)
Edit terraform.tfvars:
- secret_word = "<PASTE_SECRET_WORD>"

terraform apply

kubectl -n rearc exec -it deploy/rearc-quest -- printenv SECRET_WORD 
kubectl -n rearc rollout restart deploy/rearc-quest
kubectl -n rearc rollout status deploy/rearc-quest
kubectl -n rearc get pods

## 5) Validate required endpoints
- curl -k https://<alb_hostname>/
- curl -k https://<alb_hostname>/docker
- curl -k https://<alb_hostname>/secret_word
- curl -k https://<alb_hostname>/loadbalanced
- curl -k https://<alb_hostname>/tls