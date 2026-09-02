# Nebula API — GitHub Actions + ECR + Terraform + ECS Fargate

Este laboratório usa um nome e uma aplicação totalmente fictícios. O objetivo é demonstrar um fluxo seguro de CI/CD com GitHub Actions, AWS OIDC, ECR, Terraform, ECS Fargate e promoção de artefatos entre DEV, HML e PROD.

## Fluxo

```text
PR -> develop
  -> Maven test/package
  -> Docker build local
  -> Trivy image/filesystem

merge em develop
  -> Maven test/package
  -> Docker build
  -> Trivy image gate
  -> AWS OIDC
  -> DEV ECR push
       tags:
         1.0.0-<short-sha>
         <full-git-sha>
  -> resolve digest
  -> Terraform quality gates
  -> Terraform plan/apply DEV
  -> cria GitHub Deployment DEV com release SHA

HML workflow_dispatch
  -> busca último GitHub Deployment DEV com status success
  -> recupera automaticamente o release SHA
  -> procura a mesma tag SHA no ECR da conta HML
  -> resolve o digest do artefato replicado
  -> Terraform plan
  -> approval
  -> Terraform apply HML
  -> cria GitHub Deployment HML com o mesmo release SHA

PROD workflow_dispatch
  -> busca último GitHub Deployment HML com status success
  -> recupera automaticamente o release SHA
  -> procura a mesma tag SHA no ECR da conta PROD
  -> resolve o digest do artefato replicado
  -> Terraform plan
  -> approval obrigatório
  -> Terraform apply PROD
  -> cria GitHub Deployment PROD com o mesmo release SHA
```

Não há rebuild em HML ou PROD.

## GitHub Deployments como registro de promoção

O laboratório cria deployments explicitamente pela API do GitHub após um `terraform apply` bem-sucedido.

Cada deployment registra:

```text
environment = dev | hml | prod
ref/sha     = commit exato da release
status      = success
payload     = URI imutável da imagem usada naquele ambiente
```

Isso permite consultar depois, inclusive dias ou semanas mais tarde, qual commit foi implantado com sucesso em cada ambiente.

A promoção usa esta cadeia:

```text
DEV success deployment
      ↓ SHA
HML
      ↓ HML success deployment
PROD
```

PROD nunca busca diretamente o último DEV; ele promove somente algo que já teve deployment HML bem-sucedido.

## ECR separado por conta

Este laboratório considera um ECR por conta AWS:

```text
DEV account
  ECR nebula-api:<git-sha>

HML account
  ECR nebula-api:<git-sha>

PROD account
  ECR nebula-api:<git-sha>
```

A imagem deve ser replicada/copieda entre contas sem rebuild. A forma preferida para o exemplo é Amazon ECR cross-account replication.

O reusable `.github/workflows/reusable-resolve-promotion.yml` não faz build e não altera a imagem. Ele:

1. encontra o último deployment `success` do ambiente anterior;
2. recupera o Git SHA;
3. assume a role OIDC da conta destino;
4. procura `imageTag=<git-sha>` no ECR destino;
5. resolve o digest;
6. retorna `image_uri=repo@sha256:...` para o Terraform.

Se a imagem ainda não estiver presente no ECR destino, a pipeline falha antes do Terraform.

## Por que usar digest e não ARN de imagem

ECS espera uma imagem no formato de URI. Para deixar o deploy imutável, a pipeline passa ao Terraform:

```text
123456789012.dkr.ecr.sa-east-1.amazonaws.com/nebula-api@sha256:...
```

A pipeline também publica tags legíveis para rastreabilidade, mas o deploy usa o digest.

## Estrutura

```text
.github/workflows/
  nebula-pr.yml
  nebula-deploy-dev.yml
  nebula-promote-hml.yml
  nebula-promote-prod.yml
  reusable-maven-ci.yml
  reusable-build-ecr.yml
  reusable-resolve-promotion.yml
  reusable-terraform-deploy.yml

nebula-api/
  pom.xml
  Dockerfile
  src/
  infra/
    versions.tf
    variables.tf
    main.tf
    outputs.tf
```

## Pré-requisitos AWS

Este exemplo assume que já existem em cada conta:

- bucket S3 do backend Terraform com versioning, encryption, block public access e `use_lockfile=true`;
- repository ECR;
- VPC e subnets privadas;
- security group para as tasks ECS;
- ECS Task Execution Role com acesso ao ECR e CloudWatch Logs;
- IAM Role assumível pelo GitHub Actions via OIDC.

Também é necessário configurar replicação ou cópia imutável da imagem DEV para os ECRs de HML e PROD.

O exemplo cria via Terraform:

- CloudWatch Log Group;
- ECS Cluster;
- ECS Task Definition;
- ECS Service Fargate.

## GitHub Variables

Cadastre como Repository Variables ou Organization Variables.

### DEV

```text
DEV_AWS_REGION=sa-east-1
DEV_AWS_ACCOUNT_ID=123456789012
DEV_AWS_OIDC_ROLE_ARN=arn:aws:iam::123456789012:role/github-actions-nebula-dev
DEV_ECR_REPOSITORY=nebula-api
DEV_TF_STATE_BUCKET=company-terraform-state-dev
DEV_ECS_SUBNET_IDS_JSON=["subnet-aaaa","subnet-bbbb"]
DEV_ECS_SECURITY_GROUP_IDS_JSON=["sg-aaaa"]
DEV_ECS_EXECUTION_ROLE_ARN=arn:aws:iam::123456789012:role/ecsTaskExecutionRole
```

### HML

```text
HML_AWS_REGION=sa-east-1
HML_AWS_ACCOUNT_ID=222222222222
HML_AWS_OIDC_ROLE_ARN=arn:aws:iam::222222222222:role/github-actions-nebula-hml
HML_ECR_REPOSITORY=nebula-api
HML_TF_STATE_BUCKET=company-terraform-state-hml
HML_ECS_SUBNET_IDS_JSON=["subnet-cccc","subnet-dddd"]
HML_ECS_SECURITY_GROUP_IDS_JSON=["sg-bbbb"]
HML_ECS_EXECUTION_ROLE_ARN=arn:aws:iam::222222222222:role/ecsTaskExecutionRole
```

### PROD

```text
PROD_AWS_REGION=sa-east-1
PROD_AWS_ACCOUNT_ID=333333333333
PROD_AWS_OIDC_ROLE_ARN=arn:aws:iam::333333333333:role/github-actions-nebula-prod
PROD_ECR_REPOSITORY=nebula-api
PROD_TF_STATE_BUCKET=company-terraform-state-prod
PROD_ECS_SUBNET_IDS_JSON=["subnet-eeee","subnet-ffff"]
PROD_ECS_SECURITY_GROUP_IDS_JSON=["sg-cccc"]
PROD_ECS_EXECUTION_ROLE_ARN=arn:aws:iam::333333333333:role/ecsTaskExecutionRole
```

### GitHub App

```text
TERRAFORM_GH_APP_ID=123456
```

Account ID, region, role ARN, subnet IDs e security group IDs não são secrets.

## GitHub Secret

A private key do GitHub App deve ficar em Secret, nunca em Variable:

```text
TERRAFORM_GH_APP_PRIVATE_KEY
```

## GitHub App para módulos Terraform privados

O reusable Terraform workflow suporta módulos privados clonados por Git.

Crie um GitHub App dedicado, por exemplo:

```text
terraform-modules-reader
```

Permissões:

```text
Repository permissions:
  Contents: Read-only
```

Instale o App somente nos repositories de módulos Terraform.

A action gera um installation token com:

```yaml
owner: ${{ github.repository_owner }}
```

Sem `repositories:`. Nesse modo o token pode ler todos os repositories permitidos pela instalação do App. Isso permite módulos dinâmicos sem manter uma lista em cada pipeline.

Exemplo de módulo privado:

```hcl
module "ecs_platform" {
  source = "git::https://github.com/example-org/terraform-module-aws-ecs.git?ref=v2.4.0"
}
```

A autenticação é preparada antes de `terraform init` com:

```text
GitHub App -> installation token -> GH_TOKEN -> gh auth setup-git -> terraform init
```

Use tags ou commit SHA nos módulos; evite `?ref=main` em produção.

## AWS OIDC

Não use `AWS_ACCESS_KEY_ID` ou `AWS_SECRET_ACCESS_KEY` no GitHub.

Os reusable workflows usam:

```yaml
permissions:
  contents: read
  id-token: write
```

E depois assumem uma Role via `aws-actions/configure-aws-credentials`.

Exemplo de trust policy para DEV:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:OWNER/REPOSITORY:ref:refs/heads/develop"
        }
      }
    }
  ]
}
```

Para workflows que usam GitHub Environments no job que assume a role, ajuste a trust policy conforme o `sub` efetivamente emitido pelo OIDC para seu desenho de environment.

## GitHub permissions adicionais

O reusable de promoção usa:

```yaml
permissions:
  contents: read
  deployments: read
  id-token: write
```

O Terraform reusable grava o resultado usando:

```yaml
permissions:
  contents: read
  deployments: write
```

O `GITHUB_TOKEN` é usado somente para consultar/criar Deployments no mesmo repository.

## Backend Terraform

O Terraform contém apenas:

```hcl
backend "s3" {}
```

A pipeline injeta:

```text
bucket
key
region
encrypt=true
use_lockfile=true
```

State usado neste laboratório:

```text
nebula-api/ecs/terraform.tfstate
```

Cada conta/ambiente usa seu próprio bucket configurado nas Variables.

## Aprovação antes do apply

O reusable workflow converte o plan para JSON e procura ações contendo `delete`.

Isso captura:

- destroy;
- replace (`delete` + `create`).

DEV pode aplicar mudanças não destrutivas automaticamente. Se houver delete/replace, o job usa:

```text
dev-terraform-approval
```

HML e PROD foram configurados no exemplo com:

```yaml
always_require_approval: true
```

Portanto qualquer apply passa pelos environments:

```text
hml-terraform-approval
prod-terraform-approval
```

Crie em:

```text
Repository Settings -> Environments
```

E configure Required Reviewers conforme o plano GitHub disponível para o repository.

## Terraform quality gate

Antes do plan são executados:

```text
terraform fmt -check -recursive
terraform init
terraform validate
TFLint
Trivy IaC HIGH/CRITICAL
terraform plan
```

O plan é salvo como artifact por 1 dia e o job de apply executa exatamente esse plan.

Observação: arquivos de Terraform plan podem conter dados sensíveis. Por isso o artifact tem retenção curta e nunca deve ser commitado no Git.

## Container quality gate

No PR:

```text
mvn clean verify
docker build
Trivy image HIGH/CRITICAL
Trivy filesystem HIGH/CRITICAL
```

Após merge em `develop`, o build é repetido antes do push para garantir que o artefato publicado foi produzido a partir do commit efetivamente integrado.

## Tags do ECR

Exemplo para `pom.xml` versão `1.0.0` e Git SHA `a1b2c3d...`:

```text
nebula-api:1.0.0-a1b2c3d
nebula-api:a1b2c3d4e5f6...
```

Todos os ambientes promovem a tag de full Git SHA e fazem deploy usando:

```text
nebula-api@sha256:...
```

Recomenda-se habilitar ECR Tag Immutability.

## Como executar HML e PROD

Não é necessário informar SHA manualmente.

Para HML:

```text
Actions -> Nebula API - Promote HML -> Run workflow
```

A pipeline escolhe automaticamente o deployment DEV mais recente cujo último status é `success`.

Para PROD:

```text
Actions -> Nebula API - Promote PROD -> Run workflow
```

A pipeline escolhe automaticamente o deployment HML mais recente cujo último status é `success`.

Esse `workflow_dispatch` controla somente quando a promoção acontece; ele não pede versão/SHA.

## Reusable workflows em repositório central

Neste laboratório os reusable workflows ficam no próprio repository para facilitar testes:

```text
.github/workflows/reusable-maven-ci.yml
.github/workflows/reusable-build-ecr.yml
.github/workflows/reusable-resolve-promotion.yml
.github/workflows/reusable-terraform-deploy.yml
```

Em uso corporativo, copie esses arquivos para um repository dedicado, por exemplo:

```text
example-org/devops-workflows
```

Depois troque:

```yaml
uses: ./.github/workflows/reusable-build-ecr.yml
```

por:

```yaml
uses: example-org/devops-workflows/.github/workflows/reusable-build-ecr.yml@v1
```

E faça o mesmo para os demais.

Para maior segurança em produção, prefira fixar o reusable workflow por commit SHA:

```yaml
uses: example-org/devops-workflows/.github/workflows/reusable-build-ecr.yml@<commit-sha>
```

## Fluxo final de rastreabilidade

```text
Git commit
  abc123
     ↓
DEV ECR
  :abc123 -> sha256:XYZ
     ↓
Terraform DEV
  @sha256:XYZ
     ↓
GitHub Deployment DEV
  sha=abc123 / success
     ↓
HML promotion
  busca abc123 automaticamente
     ↓
HML ECR
  :abc123 -> sha256:XYZ
     ↓
Terraform HML
  @sha256:XYZ
     ↓
GitHub Deployment HML
  sha=abc123 / success
     ↓
PROD promotion
  busca abc123 automaticamente
     ↓
PROD ECR
  :abc123 -> sha256:XYZ
     ↓
Terraform PROD
  @sha256:XYZ
     ↓
GitHub Deployment PROD
  sha=abc123 / success
```

O princípio é: build once, promote the same artifact, never rebuild for HML or PROD.
