# Nebula API — GitHub Actions + ECR + Terraform + ECS Fargate

Este laboratório usa um nome e uma aplicação totalmente fictícios. O objetivo é demonstrar um fluxo seguro de CI/CD com GitHub Actions, AWS OIDC, ECR, Terraform e ECS Fargate.

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
  -> ECR push
       tags:
         1.0.0-<short-sha>
         <full-git-sha>
  -> resolve digest
  -> Terraform fmt / validate / TFLint / Trivy IaC
  -> Terraform plan
  -> se houver delete/replace: approval
  -> Terraform apply do mesmo plan
  -> ECS task definition recebe repo@sha256:digest
```

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
  reusable-maven-ci.yml
  reusable-build-ecr.yml
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

Este exemplo assume que já existem:

- bucket S3 do backend Terraform com versioning, encryption, block public access e `use_lockfile=true`;
- repository ECR;
- VPC e subnets privadas;
- security group para as tasks ECS;
- ECS Task Execution Role com acesso ao ECR e CloudWatch Logs;
- IAM Role assumível pelo GitHub Actions via OIDC.

O exemplo cria via Terraform:

- CloudWatch Log Group;
- ECS Cluster;
- ECS Task Definition;
- ECS Service Fargate.

## GitHub Variables

Cadastre como Repository Variables ou Organization Variables:

```text
DEV_AWS_REGION=sa-east-1
DEV_AWS_ACCOUNT_ID=123456789012
DEV_AWS_OIDC_ROLE_ARN=arn:aws:iam::123456789012:role/github-actions-nebula-dev
DEV_ECR_REPOSITORY=nebula-api
DEV_TF_STATE_BUCKET=company-terraform-state-dev
DEV_ECS_SUBNET_IDS_JSON=["subnet-aaaa","subnet-bbbb"]
DEV_ECS_SECURITY_GROUP_IDS_JSON=["sg-aaaa"]
DEV_ECS_EXECUTION_ROLE_ARN=arn:aws:iam::123456789012:role/ecsTaskExecutionRole
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

Substitua `OWNER/REPOSITORY` pelo repository real.

### Permissões da role

A role usada pelo workflow deve seguir least privilege. Ela precisa de dois conjuntos de acesso:

1. ECR push para somente o repository da aplicação;
2. Terraform para ler/escrever o state e criar/alterar os recursos ECS necessários.

Em uma plataforma mais madura, separe em duas roles:

```text
github-actions-ecr-push
github-actions-terraform-apply
```

O laboratório usa uma role configurável para simplificar.

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

## Aprovação antes do apply

O reusable workflow converte o plan para JSON e procura ações contendo `delete`.

Isso captura:

- destroy;
- replace (`delete` + `create`).

Quando existe mudança destrutiva, o job de apply usa:

```text
dev-terraform-approval
```

Crie em:

```text
Repository Settings -> Environments -> dev-terraform-approval
```

E configure Required Reviewers.

Para PROD, chame o reusable com:

```yaml
always_require_approval: true
```

Assim qualquer apply passa pelo Environment de aprovação.

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

O Terraform recebe:

```text
nebula-api@sha256:...
```

Recomenda-se habilitar ECR Tag Immutability.

## Reusable workflows em repositório central

Neste laboratório os reusable workflows ficam no próprio repository para facilitar testes:

```text
.github/workflows/reusable-maven-ci.yml
.github/workflows/reusable-build-ecr.yml
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

## Evoluções recomendadas

- separar role de ECR da role de Terraform;
- role read-only específica para `terraform plan`;
- políticas OPA/Conftest para regras corporativas;
- ALB/Target Group para expor a aplicação;
- ECS Service Connect quando houver comunicação privada entre serviços;
- assinaturas/attestations de imagem;
- SBOM;
- deployment para HML/PROD promovendo o mesmo digest, sem rebuild.

## Importante sobre promoção entre ambientes

O ideal é construir a imagem uma única vez e promover o mesmo digest:

```text
DEV -> HML -> PROD
       mesmo sha256
```

Não faça novo build para PROD. Isso garante que o artefato aprovado/testado é exatamente o que chega à produção.
