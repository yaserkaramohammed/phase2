# Phase 2: CI/CD Pipelines with GitHub Actions

## Team Information

**Group Size:** 3 students

**Team Members:**
- Student 1: Eyad Elhati (#20221050)
- Student 2: Mohammad Tamer Dukmak (#20221038)
- Student 3: Yaser Karamohammed (#20221180)

---

## Project Overview

This Phase 2 implementation demonstrates three distinct CI/CD pipeline philosophies using GitHub Actions. Each branch (dev, test, prod) deploys to the same EC2 instance but using different deployment strategies:

- **dev**: Artifact-first (package once, deploy everywhere)
- **test**: Image-first (rebuild from source, push to registry)
- **prod**: Promotion-only (pull tested image from registry)

---

## Architecture

### Three-Branch Deployment Strategy
---

## Workflow Files

### 1. Dev Pipeline (`.github/workflows/dev.yml`)

**Philosophy:** Artifact-First

**What happens:**
1. Build application from source
2. Package into `.tar.gz` artifact
3. Commit artifact to `artifacts/` folder (audit trail)
4. Build Docker image **from the artifact** (not from source)
5. Push image to ECR as `dev-latest`
6. Deploy to EC2 using `docker-compose -p dev`

**Key Points:**
- Artifact is the unit of truth
- Proves "we can deploy exactly what we built"
- Guarantees consistency between what was packaged and what runs
- Multiple builds = multiple artifact files in the repo

**Dockerfile Logic:**
```dockerfile
COPY artifacts/*.tar.gz app.tar.gz
RUN tar -xzf app.tar.gz && rm app.tar.gz
RUN pip install -r requirements.txt
```

---

### 2. Test Pipeline (`.github/workflows/test.yml`)

**Philosophy:** Image-First

**What happens:**
1. Rebuild artifact from **fresh source** (NOT from dev artifact)
2. Build Docker image from freshly-built artifact
3. Push image to AWS ECR with version tag
4. Deploy to EC2 using `docker-compose -p test`

**Key Points:**
- Proves reproducibility - we can rebuild anytime
- Fresh build every time - no dependencies on previous artifacts
- Image goes to AWS ECR registry for safekeeping
- Each commit gets a unique image tag

**Registry Strategy:**
- Use AWS ECR (Elastic Container Registry)
- Image tagged as: `<account-id>.dkr.ecr.<region>.amazonaws.com/book-shop:<version>`

---

### 3. Prod Pipeline (`.github/workflows/prod.yml`)

**Philosophy:** Promotion Only

**What happens:**
1. Read version from GitHub Actions variable: `IMAGE_VERSION`
2. Pull the **already-tested** image from ECR
3. Deploy to EC2 using `docker-compose -p prod`
4. **NO building, NO tagging, NO pushing**

**Key Points:**
- Proves "deploy only what has been tested"
- Version is single source of truth (auditable, changeable from GitHub UI)
- Guarantees prod never builds - only pulls tested images
- To promote: just update `IMAGE_VERSION` variable

**Update IMAGE_VERSION:**
- Go to: GitHub → Settings → Secrets and variables → Variables
- Edit `IMAGE_VERSION` value
- Next push to prod branch uses this version

---

## Setup Instructions

### Prerequisites

1. **AWS Account** with:
   - IAM user with ECR and EC2 permissions
   - EC2 instance running (Ubuntu 22.04+)
   - ECR repository created

2. **GitHub Repository** with:
   - 3 branches: dev, test, prod
   - Secrets and Variables configured

3. **Local Environment:**
   - Docker installed
   - git installed
   - SSH key for EC2 (.pem file)

### Step-by-Step Setup

#### 1. GitHub Secrets & Variables

**Variables (Settings → Secrets and variables → Variables):**
- `IMAGE_VERSION`: `v1.0.0` (version to deploy in prod)
- `EC2_HOST`: `<your-ec2-public-ip>` (e.g., 18.197.11.84)
- `REGISTRY_NAME`: `<aws-account-id>.dkr.ecr.<region>.amazonaws.com/book-shop`

**Secrets (Settings → Secrets and variables → Secrets):**
- `AWS_ACCESS_KEY_ID`: Your IAM access key
- `AWS_SECRET_ACCESS_KEY`: Your IAM secret key
- `EC2_SSH_KEY`: Content of your `.pem` file
- `POSTGRES_PASSWORD`: Database password
- `SECRET_KEY`: Django SECRET_KEY

#### 2. EC2 Instance Setup

```bash
# SSH into EC2
ssh -i your-key.pem ubuntu@<ec2-ip>

# Install Docker and Docker Compose
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose

# Add ubuntu to docker group
sudo usermod -aG docker ubuntu
newgrp docker

# Create deployment directory
mkdir -p /home/ubuntu/book-shop/nginx
cd /home/ubuntu/book-shop
```

#### 3. Copy Configuration to EC2

From your local PC:
```bash
# Copy docker-compose.yml
scp -i key.pem docker-compose.yml ubuntu@<ec2-ip>:/home/ubuntu/book-shop/

# Copy nginx config
scp -i key.pem nginx/nginx.conf ubuntu@<ec2-ip>:/home/ubuntu/book-shop/nginx/
```

---

## How It Works: Three Deployments, One Server

### Port Strategy

Each branch uses a different Docker Compose project name to avoid conflicts:

| Branch | Compose Project | Backend Port | Database Port | Status |
|--------|-----------------|--------------|---------------|--------|
| dev | dev | 8001 | 5432 | development |
| test | test | 8002 | 5433 | testing |
| prod | prod | 8000 | 5434 | production |

### Network Isolation

Each compose project has its own:
- Docker network (`bookshop_network`)
- Container instances (db, backend, nginx)
- Volume mounts
- Environment variables

This prevents conflicts even though they run on the same EC2 instance.

### Docker Compose Configuration

The `docker-compose.yml` uses environment variables:

```yaml
backend:
  image: ${REGISTRY_NAME:-book-shop}:${IMAGE_TAG:-latest}
  environment:
    POSTGRES_PASSWORD: ${{ secrets.POSTGRES_PASSWORD }}
    SECRET_KEY: ${{ secrets.SECRET_KEY }}
```

Each workflow sets these values when deploying.

---

## File Structure
---

## Deployment Workflow Example

### Dev Branch Push

```bash
git checkout dev
echo "test" >> README.md
git add README.md
git commit -m "Test commit"
git push origin dev
```

**What happens automatically:**
1. GitHub detects push to dev
2. Triggers `dev.yml` workflow
3. Builds artifact → commits to artifacts/ folder
4. Builds Docker image from artifact
5. Pushes to ECR as `book-shop:dev-latest`
6. Deploys: `docker-compose -p dev up -d`
7. App running at: `http://<ec2-ip>:8001`

### Test Branch Push

```bash
git checkout test
git merge dev    # Bring in changes
git push origin test
```

**What happens automatically:**
1. GitHub detects push to test
2. Triggers `test.yml` workflow
3. Builds **fresh** artifact from source
4. Builds Docker image from fresh artifact
5. Pushes to ECR as `book-shop:<short-sha>`
6. Deploys: `docker-compose -p test up -d`
7. App running at: `http://<ec2-ip>:8002`

### Prod Deployment

```bash
# Update IMAGE_VERSION variable in GitHub
# Settings → Secrets and variables → Variables
# Change IMAGE_VERSION to the version you tested (e.g., "abc12345")
git push origin prod
```

**What happens automatically:**
1. GitHub detects push to prod
2. Triggers `prod.yml` workflow
3. Reads `IMAGE_VERSION` variable
4. Pulls image from ECR: `book-shop:<IMAGE_VERSION>`
5. Deploys: `docker-compose -p prod up -d`
6. App running at: `http://<ec2-ip>:80` (main port)

---

## Important Design Decisions

### 1. Group of 3 → AWS ECR

Since the group has 3 students, we use AWS ECR (not Docker Hub) to:
- Store images securely in AWS
- Enable proper access control
- Integrate with AWS IAM

### 2. docker-compose.yml Uses Image Tags

Rather than `build: .`, we use explicit image tags:
```yaml
backend:
  image: ${REGISTRY_NAME}:${IMAGE_TAG}
```

This:
- Allows the same compose file to be reused
- Prevents accidental rebuilds in production
- Guarantees we deploy what we tested

### 3. Artifacts Committed to Repo

The `artifacts/` folder contains all build artifacts:
- Creates an audit trail
- Proves reproducibility
- Allows rollback to any previous version
- Shows progression of builds

### 4. EC2 Single Instance, Multiple Compose Projects

Using `-p dev`, `-p test`, `-p prod` flags ensures:
- Each deployment is isolated
- No port conflicts
- Easy cleanup: `docker-compose -p dev down`
- Cost-effective (single EC2 instance)

---

## Known Issues & Troubleshooting

### Issue 1: Workflow Not Triggering

**Symptom:** Push to branch but workflow doesn't run

**Solutions:**
1. Check workflow file syntax (YAML indentation)
2. Verify branch name matches `on: branches:`
3. Confirm workflow file is in `.github/workflows/` folder
4. Check GitHub Actions is enabled (Settings → Actions)

### Issue 2: Docker Build Fails

**Symptom:** Workflow fails at "Build Docker image"

**Solutions:**
1. Verify Dockerfile exists and is valid
2. Check that `artifacts/` folder exists with artifact file
3. Ensure `requirements.txt` is in artifact
4. Verify base image (`python:3.11-slim`) is accessible

### Issue 3: ECR Login Fails

**Symptom:** "Invalid username or password"

**Solutions:**
1. Verify AWS credentials in GitHub Secrets
2. Confirm IAM user has ECR permissions:
   - `ecr:GetDownloadUrlForLayer`
   - `ecr:BatchGetImage`
   - `ecr:PutImage`
3. Check ECR repository exists in correct region

### Issue 4: SSH Deploy Fails

**Symptom:** "Permission denied" or "Connection refused"

**Solutions:**
1. Verify EC2_SSH_KEY secret contains full .pem file content
2. Confirm EC2_HOST is correct public IP
3. Check EC2 security group allows SSH (port 22)
4. Ensure ubuntu user can run docker (added to docker group)

### Issue 5: Container Ports Already in Use

**Symptom:** `Error: Cannot start service backend: port is already allocated`

**Solutions:**
1. Check no other containers use the port
2. Use different ports for dev/test/prod (8001, 8002, 8000)
3. Kill conflicting containers: `docker kill <container-id>`
4. Use compose project names correctly: `-p dev`, `-p test`, `-p prod`

---

## Testing the Workflows

### Manual Test Steps

1. **Test Dev Pipeline:**
```bash
   git checkout dev
   echo "# Dev Test" >> README.md
   git add . && git commit -m "test dev"
   git push origin dev
```
   Check: GitHub Actions → watch workflow run

2. **Test Test Pipeline:**
```bash
   git checkout test
   git merge dev
   git push origin test
```
   Check: GitHub Actions → watch workflow run

3. **Test Prod Pipeline:**
   - Go to GitHub Repo Settings → Secrets and variables
   - Find `IMAGE_VERSION`
   - Update to a valid image tag from test build
   - Push to prod branch
```bash
   git checkout prod
   git push origin prod
```

### Verification

After each workflow:
```bash
# SSH into EC2
ssh -i key.pem ubuntu@<ec2-ip>

# Check running containers
docker ps

# Check logs
docker-compose -p dev logs backend
docker-compose -p test logs backend
docker-compose -p prod logs backend

# Test app
curl http://localhost:8001/  # dev
curl http://localhost:8002/  # test
curl http://localhost/       # prod (nginx)
```

---

## Security Considerations

### Secrets Management

- ✅ Secrets stored in GitHub (encrypted)
- ✅ `.env` file NOT committed (in `.gitignore`)
- ✅ Artifacts don't contain secrets
- ✅ EC2 SSH key in GitHub Secrets

### Best Practices

1. **Rotate credentials** regularly
2. **Use IAM roles** instead of access keys (when possible)
3. **Limit ECR permissions** to minimum needed
4. **Monitor EC2 security groups** for open ports
5. **Use HTTPS** for any external communication

---

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Phase 2 Assignment](./phase2_pipeline_assignment.pdf)

---

## Summary

This Phase 2 implementation demonstrates:

✅ **Artifact-First (dev):** Consistent, reproducible deployments
✅ **Image-First (test):** Reliable, testable builds
✅ **Promotion-Only (prod):** Safe, auditable deployments

All three branches coexist on one EC2 instance using Docker Compose project isolation, proving that real-world CI/CD pipelines can be sophisticated while remaining cost-effective.

---

**Last Updated:** May 19, 2026
